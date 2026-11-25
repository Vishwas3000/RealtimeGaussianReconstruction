//
//  DatasetEncoder.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 1/2/21.
//  Copyright © 2021 Stray Robots. All rights reserved.
//
//  RoadCapture changes (TeslaRender D-013): depth is optional; adds frames.csv (tracking state,
//  exposure, lock, heat per frame), gps.csv and capture_info.json.
//

import Foundation
import ARKit
import CryptoKit
import CoreMotion
import CoreLocation
import ImageIO

class DatasetEncoder {
    enum Status {
        case allGood
        case videoEncodingError
        case directoryCreationError
    }
    private let rgbEncoder: VideoEncoder
    private let depthEncoder: DepthEncoder?            // nil when LiDAR depth is off
    private let confidenceEncoder: ConfidenceEncoder?
    private let datasetDirectory: URL
    private let odometryEncoder: OdometryEncoder
    private let imuEncoder: IMUEncoder
    private let distortionEncoder: DistortionEncoder
    private let frameEncoder: FrameMetadataEncoder
    private let locationEncoder: LocationEncoder
    private var lastFrame: ARFrame?
    private var dispatchGroup = DispatchGroup()
    private var currentFrame: Int = -1
    private var savedFrames: Int = 0
    private var finished = false
    private let frameInterval: Int // Only save every frameInterval-th frame.
    private let encodingSemaphore = DispatchSemaphore(value: 3) // Limit queued frames to avoid ARFrame retention
    public let id: UUID
    public let rgbFilePath: URL // Relative to app document directory.
    public let depthFilePath: URL // Relative to app document directory.
    public let cameraMatrixPath: URL
    public let odometryPath: URL
    public let imuPath: URL
    public var status = Status.allGood
    private let queue: DispatchQueue

    private var latestAccelerometerData: (timestamp: Double, data: simd_double3)?
    private var latestGyroscopeData: (timestamp: Double, data: simd_double3)?


    init(arConfiguration: ARWorldTrackingConfiguration, fpsDivider: Int = 1, depthEnabled: Bool = true, captureInfo: [String: Any] = [:]) {
        self.frameInterval = fpsDivider
        self.queue = DispatchQueue(label: "encoderQueue")

        let format = arConfiguration.videoFormat
        let width = format.imageResolution.width
        let height = format.imageResolution.height
        let savedFps = max(1, format.framesPerSecond / max(1, fpsDivider))
        var theId: UUID = UUID()
        datasetDirectory = DatasetEncoder.createDirectory(id: &theId)
        self.id = theId
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb.mp4")
        self.rgbEncoder = VideoEncoder(file: self.rgbFilePath, width: width, height: height, fps: savedFps)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
        if depthEnabled {
            self.depthEncoder = DepthEncoder(outDirectory: self.depthFilePath)
            let confidenceFilePath = datasetDirectory.appendingPathComponent("confidence", isDirectory: true)
            self.confidenceEncoder = ConfidenceEncoder(outDirectory: confidenceFilePath)
        } else {
            self.depthEncoder = nil
            self.confidenceEncoder = nil
        }
        self.cameraMatrixPath = datasetDirectory.appendingPathComponent("camera_matrix.csv", isDirectory: false)
        self.odometryPath = datasetDirectory.appendingPathComponent("odometry.csv", isDirectory: false)
        self.odometryEncoder = OdometryEncoder(url: self.odometryPath)
        self.imuPath = datasetDirectory.appendingPathComponent("imu.csv", isDirectory: false)
        self.imuEncoder = IMUEncoder(url: self.imuPath)
        self.distortionEncoder = DistortionEncoder(datasetDirectory: datasetDirectory)
        self.frameEncoder = FrameMetadataEncoder(url: datasetDirectory.appendingPathComponent("frames.csv"))
        self.locationEncoder = LocationEncoder(url: datasetDirectory.appendingPathComponent("gps.csv"))

        var info = captureInfo
        info["width"] = Int(width)
        info["height"] = Int(height)
        info["camera_fps"] = format.framesPerSecond
        info["saved_fps"] = savedFps
        info["depth_enabled"] = depthEnabled
        DatasetEncoder.writeJSON(info, to: datasetDirectory.appendingPathComponent("capture_info.json"))
    }

    func add(frame: ARFrame, cameraLocked: Bool = false) {
        let totalFrames: Int = currentFrame
        currentFrame = currentFrame + 1
        if (currentFrame % frameInterval != 0) {
            return
        }
        // Drop frame if encoding is backed up to avoid accumulating ARFrame references.
        guard encodingSemaphore.wait(timeout: .now()) == .success else {
            return
        }
        let frameNumber: Int = savedFrames
        savedFrames = savedFrames + 1
        dispatchGroup.enter()
        queue.async {
            defer {
                self.encodingSemaphore.signal()
                self.dispatchGroup.leave()
            }
            if let depthEncoder = self.depthEncoder {
                if let sceneDepth = frame.sceneDepth {
                    depthEncoder.encodeFrame(frame: sceneDepth.depthMap, frameNumber: frameNumber)
                    if let confidence = sceneDepth.confidenceMap {
                        self.confidenceEncoder?.encodeFrame(frame: confidence, frameNumber: frameNumber)
                    } else {
                        print("warning: confidence map missing.")
                    }
                } else {
                    print("warning: scene depth missing.")
                }
            }
            self.rgbEncoder.add(frame: VideoEncoderInput(buffer: frame.capturedImage, time: frame.timestamp), currentFrame: totalFrames)
            self.odometryEncoder.add(frame: frame, currentFrame: frameNumber)
            self.frameEncoder.add(frame: frame, frameNumber: frameNumber, cameraLocked: cameraLocked)
            self.distortionEncoder.add(frame: frame, currentFrame: frameNumber)
            self.lastFrame = frame
        }
    }

    // Called on the main thread by the location manager.
    func add(location: CLLocation) {
        guard !finished else { return }
        // CLLocation carries a wall-clock time; move it onto the uptime clock the other files use.
        let uptime = ProcessInfo.processInfo.systemUptime - Date().timeIntervalSince(location.timestamp)
        dispatchGroup.enter()
        queue.async {
            defer { self.dispatchGroup.leave() }
            self.locationEncoder.add(location: location, uptime: uptime)
        }
    }

   func addRawAccelerometer(data: CMAccelerometerData) {
        let acceleration = simd_double3(data.acceleration.x, data.acceleration.y, data.acceleration.z)
        latestAccelerometerData = (timestamp: data.timestamp, data: acceleration)
        tryWritingIMUData()
    }

    func addRawGyroscope(data: CMGyroData) {
        let rotationRate = simd_double3(data.rotationRate.x, data.rotationRate.y, data.rotationRate.z)
        latestGyroscopeData = (timestamp: data.timestamp, data: rotationRate)
        tryWritingIMUData()
    }

    private func tryWritingIMUData() {
        guard
            let accelerometer = latestAccelerometerData,
            let gyroscope = latestGyroscopeData
        else {
            return
        }

        // Write the row to the CSV with the most recent timestamp
        let timestamp = max(accelerometer.timestamp, gyroscope.timestamp)
        imuEncoder.add(
            timestamp: timestamp,
            linear: accelerometer.data,
            angular: gyroscope.data
        )

        // Clear the buffers after writing
        latestAccelerometerData = nil
        latestGyroscopeData = nil
    }

    func wrapUp() {
        finished = true
        dispatchGroup.wait()
        self.rgbEncoder.finishEncoding()
        self.imuEncoder.done()
        self.odometryEncoder.done()
        self.distortionEncoder.done()
        self.frameEncoder.done()
        self.locationEncoder.done()
        writeIntrinsics()
        // Any failing encoder fails the recording (each check used to overwrite the previous one).
        var failed = false
        if case .error = self.rgbEncoder.status {
            failed = true
        }
        if case .frameEncodingError? = self.depthEncoder?.status {
            failed = true
            print("Something went wrong encoding depth.")
        }
        if case .encodingError? = self.confidenceEncoder?.status {
            failed = true
            print("Something went wrong encoding confidence values.")
        }
        status = failed ? .videoEncodingError : .allGood
    }

    private func writeIntrinsics() {
        if let cameraMatrix = lastFrame?.camera.intrinsics {
            let rows = cameraMatrix.transpose.columns
            var csv: [String] = []
            for row in [rows.0, rows.1, rows.2] {
                let csvLine = "\(row.x), \(row.y), \(row.z)"
                csv.append(csvLine)
            }
            let contents = csv.joined(separator: "\n")
            do {
                try contents.write(to: self.cameraMatrixPath, atomically: true, encoding: String.Encoding.utf8)
            } catch let error {
                print("Could not write camera matrix. \(error.localizedDescription)")
            }
        }
    }

    static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static private func writeJSON(_ object: [String: Any], to url: URL) {
        do {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url)
        } catch let error {
            print("Could not write \(url.lastPathComponent). \(error.localizedDescription)")
        }
    }

    static private func createDirectory(id: inout UUID) -> URL {
        let directoryId = hashUUID(id: id)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var directory = URL(fileURLWithPath: directoryId, relativeTo: url)
        if FileManager.default.fileExists(atPath: directory.absoluteString) {
            // Just in case the first 5 characters clash, try again.
            id = UUID()
            directory = DatasetEncoder.createDirectory(id: &id)
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("Error creating directory. \(error), \(error.userInfo)")
        }
        return directory
    }

    static private func hashUUID(id: UUID) -> String {
        var hasher: SHA256 = SHA256()
        hasher.update(data: id.uuidString.data(using: .ascii)!)
        let digest = hasher.finalize()
        var string = ""
        digest.makeIterator().prefix(5).forEach { (byte: UInt8) in
            string += String(format: "%02x", byte)
        }
        print("Hash: \(string)")
        return string
    }
}

// RoadCapture: the new CSV outputs live here so the Xcode project's file list stays unchanged.

final class CSVWriter {
    private let handle: FileHandle?

    init(url: URL, header: String) {
        FileManager.default.createFile(atPath: url.path, contents: (header + "\n").data(using: .utf8))
        handle = try? FileHandle(forWritingTo: url)
        handle?.seekToEndOfFile()
        if handle == nil {
            print("Can't open \(url.lastPathComponent) for writing.")
        }
    }

    func write(_ fields: [String]) {
        handle?.write((fields.joined(separator: ", ") + "\n").data(using: .utf8)!)
    }

    func close() {
        try? handle?.close()
    }
}

/// frames.csv: one row per saved frame, in the same order as odometry.csv and rgb.mp4.
final class FrameMetadataEncoder {
    private let csv: CSVWriter

    init(url: URL) {
        csv = CSVWriter(url: url, header: "timestamp, frame, tracking_state, tracking_reason, exposure_duration, exposure_offset, exif_exposure_time, exif_iso, exif_brightness, camera_locked, thermal_state, has_depth")
    }

    func add(frame: ARFrame, frameNumber: Int, cameraLocked: Bool) {
        let tracking = FrameMetadataEncoder.describe(frame.camera.trackingState)
        var exif = (exposure: "", iso: "", brightness: "")
        if #available(iOS 16.0, *) {
            exif = FrameMetadataEncoder.exifValues(frame.exifData)
        }
        csv.write([
            "\(frame.timestamp)",
            String(format: "%06d", frameNumber),
            tracking.state,
            tracking.reason,
            "\(frame.camera.exposureDuration)",
            "\(frame.camera.exposureOffset)",
            exif.exposure,
            exif.iso,
            exif.brightness,
            cameraLocked ? "1" : "0",
            "\(ProcessInfo.processInfo.thermalState.rawValue)",
            frame.sceneDepth != nil ? "1" : "0",
        ])
    }

    func done() {
        csv.close()
    }

    static func describe(_ state: ARCamera.TrackingState) -> (state: String, reason: String) {
        switch state {
        case .normal:
            return ("normal", "")
        case .notAvailable:
            return ("not_available", "")
        case .limited(let reason):
            switch reason {
            case .initializing: return ("limited", "initializing")
            case .excessiveMotion: return ("limited", "excessive_motion")
            case .insufficientFeatures: return ("limited", "insufficient_features")
            case .relocalizing: return ("limited", "relocalizing")
            @unknown default: return ("limited", "unknown")
            }
        }
    }

    // ARFrame.exifData may hold the EXIF keys directly or under "{Exif}"; read either.
    static func exifValues(_ exif: [String: Any]) -> (exposure: String, iso: String, brightness: String) {
        let d = (exif[kCGImagePropertyExifDictionary as String] as? [String: Any]) ?? exif
        let exposure = (d[kCGImagePropertyExifExposureTime as String] as? NSNumber).map { "\($0.doubleValue)" } ?? ""
        let iso = ((d[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first).map { "\($0.doubleValue)" } ?? ""
        let brightness = (d[kCGImagePropertyExifBrightnessValue as String] as? NSNumber).map { "\($0.doubleValue)" } ?? ""
        return (exposure, iso, brightness)
    }
}

/// gps.csv: every Core Location fix while recording. `timestamp` is on the uptime clock.
final class LocationEncoder {
    private let csv: CSVWriter

    init(url: URL) {
        csv = CSVWriter(url: url, header: "timestamp, unix_time, latitude, longitude, altitude, horizontal_accuracy, vertical_accuracy, speed, speed_accuracy, course, course_accuracy")
    }

    func add(location: CLLocation, uptime: TimeInterval) {
        var courseAccuracy = ""
        if #available(iOS 13.4, *) {
            courseAccuracy = "\(location.courseAccuracy)"
        }
        csv.write([
            "\(uptime)",
            "\(location.timestamp.timeIntervalSince1970)",
            String(format: "%.8f", location.coordinate.latitude),
            String(format: "%.8f", location.coordinate.longitude),
            "\(location.altitude)",
            "\(location.horizontalAccuracy)",
            "\(location.verticalAccuracy)",
            "\(location.speed)",
            "\(location.speedAccuracy)",
            "\(location.course)",
            courseAccuracy,
        ])
    }

    func done() {
        csv.close()
    }
}
