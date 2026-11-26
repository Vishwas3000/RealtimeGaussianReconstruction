//
//  MultiCamRecorder.swift
//  RoadCapture (TeslaRender D-014)
//
//  Multi-lens recording without ARKit. One of Apple's combined cameras (dual-wide or triple) streams its lenses
//  in hardware sync. Each lens goes to its own HEVC file plus a CSV of per-frame timestamp, lens parameters and
//  exposure. Motion sensors and GPS are logged on the same clock, so camera positions can be computed afterwards
//  (visual-inertial odometry), as D-014 plans.
//

import AVFoundation
import CoreMotion
import CoreLocation
import ImageIO
import UIKit
import simd

enum MultiLensPreset: Int, CaseIterable {
    case wideUltraWide4K = 0  // probe: 4K each, hardware-synced (0.11 ms), heat cost 0.68
    case allLenses1080 = 1    // probe: 1080p each (4K doesn't fit), synced, heat cost 1.71

    var label: String {
        switch self {
        case .wideUltraWide4K: return "Wide + ultra-wide, 4K"
        case .allLenses1080: return "All 3 lenses, 1080p"
        }
    }

    var shortLabel: String {
        switch self {
        case .wideUltraWide4K: return "2 lenses · 4K"
        case .allLenses1080: return "3 lenses · 1080p"
        }
    }

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .wideUltraWide4K: return .builtInDualWideCamera
        case .allLenses1080: return .builtInTripleCamera
        }
    }
}

/// Longest shutter auto exposure may use. Fast keeps road footage sharp but goes dark indoors or at night
/// (measured: ISO pinned at 2000/3200 and near-black frames indoors at 1/1000 s).
enum ShutterCap: Int, CaseIterable {
    case fast = 0     // ≤ 1/1000 s: daylight driving (auto exposure picks ~1/5000 s in sun anyway)
    case medium = 1   // ≤ 1/250 s: overcast, dusk
    case auto = 2     // no cap: night, indoor tests (motion blur at speed)

    var label: String {
        switch self {
        case .fast: return "≤1/1000"
        case .medium: return "≤1/250"
        case .auto: return "Auto"
        }
    }

    var maxDuration: CMTime? {
        switch self {
        case .fast: return CMTime(value: 1, timescale: 1000)
        case .medium: return CMTime(value: 1, timescale: 250)
        case .auto: return nil
        }
    }
}

/// One lens of the combined camera. `writer` is only touched on `queue`.
final class LensStream {
    let name: String
    let output: AVCaptureVideoDataOutput
    let queue: DispatchQueue
    var width = 0
    var height = 0
    var writer: LensWriter?
    private let lock = NSLock()
    private var delivered = 0
    private var dropped = 0

    init(name: String, output: AVCaptureVideoDataOutput) {
        self.name = name
        self.output = output
        self.queue = DispatchQueue(label: "lens.\(name)")
    }

    func count(delivered d: Int = 0, dropped x: Int = 0) {
        lock.lock(); delivered += d; dropped += x; lock.unlock()
    }

    func counts() -> (delivered: Int, dropped: Int) {
        lock.lock(); defer { lock.unlock() }
        return (delivered, dropped)
    }
}

/// Writes one lens: `<lens>.mp4` (HEVC) and `<lens>.csv`, one row per frame that made it into the video.
final class LensWriter {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let csv: CSVWriter
    private var started = false
    private(set) var frames = 0
    private(set) var dropped = 0
    /// Every lens records the same window, so synchronised lenses keep exactly the same frames.
    var startAt = CMTime.zero
    var stopAt = CMTime.positiveInfinity

    init(video: URL, csv csvURL: URL, width: Int, height: Int, fps: Int) throws {
        writer = try AVAssetWriter(outputURL: video, fileType: .mp4)
        let bitRate = Int(Double(width * height * fps) * 0.2) // ~0.2 bit per pixel, as in the ARKit mode
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitRate, AVVideoExpectedSourceFrameRateKey: fps],
        ])
        input.expectsMediaDataInRealTime = true
        guard writer.canAdd(input) else {
            throw NSError(domain: "RoadCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Can't add a video input for \(video.lastPathComponent)"])
        }
        writer.add(input)
        csv = CSVWriter(url: csvURL, header: "timestamp, frame, fx, fy, cx, cy, exposure_time, iso, thermal_state")
    }

    /// Returns false when the frame could not be written (the encoder was busy); the caller counts it.
    @discardableResult
    func append(_ buffer: CMSampleBuffer) -> Bool {
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        if CMTimeCompare(pts, startAt) < 0 || CMTimeCompare(pts, stopAt) > 0 {
            return true // outside the shared recording window: skipped on purpose, not dropped
        }
        if !started {
            guard writer.startWriting() else { dropped += 1; return false }
            writer.startSession(atSourceTime: pts) // the movie starts at this lens's first frame
            started = true
        }
        guard input.isReadyForMoreMediaData, input.append(buffer) else {
            dropped += 1
            return false
        }
        let k = MultiCamRecorder.intrinsics(buffer)
        let exif = MultiCamRecorder.exif(buffer)
        csv.write([
            "\(pts.seconds)", String(format: "%06d", frames), k.fx, k.fy, k.cx, k.cy, exif.exposure, exif.iso,
            "\(ProcessInfo.processInfo.thermalState.rawValue)",
        ])
        frames += 1
        return true
    }

    func finish(_ done: @escaping () -> Void) {
        csv.close()
        guard started, writer.status == .writing else {
            writer.cancelWriting()
            done()
            return
        }
        input.markAsFinished()
        writer.finishWriting(completionHandler: done)
    }
}

final class MultiCamRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureMultiCamSession()
    let previewLayer: AVCaptureVideoPreviewLayer
    private let sessionQueue = DispatchQueue(label: "multicam.session")
    private(set) var streams: [LensStream] = []
    private(set) var device: AVCaptureDevice?
    private(set) var preset: MultiLensPreset = .wideUltraWide4K
    private var shutterCap: ShutterCap = .fast
    private var locked = false
    private let motion = CMMotionManager()
    private let imuQueue = OperationQueue()
    private let imuLock = NSLock()
    private var imu: IMUEncoder?
    private var latestAccel: (t: Double, v: simd_double3)?
    private var latestGyro: (t: Double, v: simd_double3)?
    private let gpsQueue = DispatchQueue(label: "multicam.gps")
    private var gps: LocationEncoder?
    private var directory: URL?
    private var startedAt: Date?

    var lensNames: [String] { streams.map { $0.name } }
    var formatLabel: String { streams.first.map { "\($0.width)x\($0.height)" } ?? "–" }

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
        previewLayer.videoGravity = .resizeAspect
        super.init()
        imuQueue.maxConcurrentOperationCount = 1 // accelerometer and gyro handlers share state
        imuQueue.qualityOfService = .userInitiated
    }

    // MARK: Session

    /// Builds the session for a preset and starts the preview. `done` gets nil or an error message.
    func configure(_ preset: MultiLensPreset, done: @escaping (String?) -> Void) {
        sessionQueue.async {
            let error = self.build(preset)
            if error == nil && !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { done(error) }
        }
    }

    func stopPreview() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func build(_ preset: MultiLensPreset) -> String? {
        guard AVCaptureMultiCamSession.isMultiCamSupported else { return "This iPhone can't run several cameras at once." }
        guard let device = AVCaptureDevice.default(preset.deviceType, for: .video, position: .back) else {
            return "This iPhone has no camera for \"\(preset.label)\"."
        }
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        session.connections.forEach { session.removeConnection($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.inputs.forEach { session.removeInput($0) }
        streams = []
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            session.commitConfiguration()
            return "Can't open the \(CameraProbe.name(device)) camera."
        }
        session.addInputWithNoConnections(input)

        // Wide first, so it is the reference lens in the files and the gallery.
        let order = ["wide", "ultraWide", "tele"]
        let lenses = device.constituentDevices.sorted {
            (order.firstIndex(of: CameraProbe.name($0)) ?? 9) < (order.firstIndex(of: CameraProbe.name($1)) ?? 9)
        }
        var previewPort: AVCaptureInput.Port?
        for lens in lenses {
            guard let port = input.ports(for: .video, sourceDeviceType: lens.deviceType, sourceDevicePosition: lens.position).first else { continue }
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true // late frames are counted in didDrop, not hidden
            let stream = LensStream(name: CameraProbe.name(lens), output: output)
            output.setSampleBufferDelegate(self, queue: stream.queue)
            guard session.canAddOutput(output) else { continue }
            session.addOutputWithNoConnections(output)
            let connection = AVCaptureConnection(inputPorts: [port], output: output)
            guard session.canAddConnection(connection) else {
                session.removeOutput(output)
                continue
            }
            session.addConnection(connection)
            if connection.isCameraIntrinsicMatrixDeliverySupported { connection.isCameraIntrinsicMatrixDeliveryEnabled = true }
            if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .off }
            streams.append(stream)
            if previewPort == nil { previewPort = port }
        }
        if let port = previewPort {
            let preview = AVCaptureConnection(inputPort: port, videoPreviewLayer: previewLayer)
            if session.canAddConnection(preview) {
                session.addConnection(preview)
                if preview.isVideoRotationAngleSupported(90) { preview.videoRotationAngle = 90 } // upright in the portrait UI
            }
        }
        guard streams.count >= 2 else {
            session.commitConfiguration()
            return "Only \(streams.count) lens stream could be set up."
        }

        // Largest multi-camera 30 fps format, shrunk until the hardware cost fits (as the probe measured).
        let formats = CameraProbe.multicamFormats(device)
        guard !formats.isEmpty else {
            session.commitConfiguration()
            return "No multi-camera 30 fps format."
        }
        var index = 0
        CameraProbe.setFormat(device, formats[index])
        session.commitConfiguration()
        while session.hardwareCost > 1.0 && index + 1 < formats.count {
            index += 1
            session.beginConfiguration()
            CameraProbe.setFormat(device, formats[index])
            session.commitConfiguration()
        }
        let dims = CMVideoFormatDescriptionGetDimensions(formats[index].formatDescription)
        for stream in streams {
            stream.width = Int(dims.width)
            stream.height = Int(dims.height)
        }
        self.device = device
        self.preset = preset
        applyAutoSettings(device)
        return nil
    }

    /// Auto focus, exposure and white balance, with the shutter capped (ShutterCap) against motion blur; auto exposure
    /// raises ISO instead. Every frame's real exposure goes into the lens CSVs.
    private func applyAutoSettings(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                let format = device.activeFormat
                if let cap = shutterCap.maxDuration,
                   CMTimeCompare(cap, format.minExposureDuration) >= 0 && CMTimeCompare(cap, format.maxExposureDuration) <= 0 {
                    device.activeMaxExposureDuration = cap
                } else {
                    device.activeMaxExposureDuration = .invalid // back to the format's default
                }
            }
            device.unlockForConfiguration()
        } catch {
            print("multicam: can't set camera modes. \(error.localizedDescription)")
        }
    }

    /// Lock focus, exposure and white balance where they are now; unlocking returns to the auto settings.
    func setShutterCap(_ cap: ShutterCap) {
        sessionQueue.async {
            self.shutterCap = cap
            if let device = self.device, !self.locked { self.applyAutoSettings(device) }
        }
    }

    func setLocked(_ locked: Bool) {
        sessionQueue.async {
            self.locked = locked
            guard let device = self.device else { return }
            if !locked {
                self.applyAutoSettings(device)
                return
            }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.locked) { device.focusMode = .locked }
                if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
                if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
                device.unlockForConfiguration()
            } catch {
                print("multicam: can't lock the camera. \(error.localizedDescription)")
            }
        }
    }

    // MARK: Recording

    func startRecording(info: [String: Any], done: @escaping (String?) -> Void) {
        sessionQueue.async {
            guard let device = self.device, !self.streams.isEmpty else {
                DispatchQueue.main.async { done("The cameras aren't ready yet.") }
                return
            }
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let name = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(10))
            let directory = documents.appendingPathComponent(name, isDirectory: true)
            var writers: [LensWriter] = []
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                // Create every writer first: creating one takes ~200 ms (measured), which made the second lens
                // start 6 frames late when each was started as soon as it was created.
                for stream in self.streams {
                    writers.append(try LensWriter(video: directory.appendingPathComponent("\(stream.name).mp4"),
                                                  csv: directory.appendingPathComponent("\(stream.name).csv"),
                                                  width: stream.width, height: stream.height, fps: 30))
                }
            } catch {
                DispatchQueue.main.async { done("Can't start recording: \(error.localizedDescription)") }
                return
            }
            // One start time for all lenses, slightly ahead so every writer is in place before it.
            let clock = self.session.synchronizationClock ?? CMClockGetHostTimeClock()
            let startAt = CMTimeAdd(CMClockGetTime(clock), CMTime(value: 1, timescale: 10))
            for (stream, writer) in zip(self.streams, writers) {
                writer.startAt = startAt
                stream.queue.sync { stream.writer = writer }
            }
            self.gpsQueue.sync { self.gps = LocationEncoder(url: directory.appendingPathComponent("gps.csv")) }
            self.imuLock.lock()
            self.imu = IMUEncoder(url: directory.appendingPathComponent("imu.csv"))
            self.imuLock.unlock()
            self.startIMU()
            self.directory = directory
            self.startedAt = Date()

            var captureInfo = info
            captureInfo["mode"] = "multi-lens"
            captureInfo["preset"] = self.preset.label
            captureInfo["camera"] = CameraProbe.name(device)
            captureInfo["lenses"] = self.lensNames
            captureInfo["width"] = self.streams[0].width
            captureInfo["height"] = self.streams[0].height
            captureInfo["camera_fps"] = 30
            captureInfo["gdc_enabled"] = device.isGeometricDistortionCorrectionSupported && device.isGeometricDistortionCorrectionEnabled
            captureInfo["max_exposure_s"] = device.activeMaxExposureDuration.seconds
            captureInfo["shutter_cap"] = self.shutterCap.label
            captureInfo["extrinsics"] = CameraProbe.extrinsics(device.constituentDevices)
            captureInfo["imu"] = "imu.csv: Core Motion accelerometer in g and gyroscope in rad/s, device axes"
            captureInfo["clock"] = "All CSV timestamps are seconds on the host/uptime clock (sample buffer PTS, Core Motion, ProcessInfo.systemUptime)."
            if let data = try? JSONSerialization.data(withJSONObject: captureInfo, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: directory.appendingPathComponent("capture_info.json"))
            }
            DispatchQueue.main.async { done(nil) }
        }
    }

    /// Finishes every file. `done` gets the recording folder and its length in seconds.
    func stopRecording(done: @escaping (URL?, TimeInterval) -> Void) {
        sessionQueue.async {
            self.stopIMU()
            // One stop time for all lenses; wait briefly so frames captured before it reach every writer.
            let clock = self.session.synchronizationClock ?? CMClockGetHostTimeClock()
            let stopAt = CMClockGetTime(clock)
            for stream in self.streams {
                stream.queue.sync { stream.writer?.stopAt = stopAt }
            }
            Thread.sleep(forTimeInterval: 0.15)
            let group = DispatchGroup()
            for stream in self.streams {
                group.enter()
                stream.queue.async {
                    guard let writer = stream.writer else { group.leave(); return }
                    stream.writer = nil
                    writer.finish { group.leave() }
                }
            }
            group.wait()
            self.gpsQueue.sync {
                self.gps?.done()
                self.gps = nil
            }
            self.imuLock.lock()
            self.imu?.done()
            self.imu = nil
            self.imuLock.unlock()
            let duration = self.startedAt.map { Date().timeIntervalSince($0) } ?? 0
            let directory = self.directory
            self.directory = nil
            self.startedAt = nil
            DispatchQueue.main.async { done(directory, duration) }
        }
    }

    /// Called on the main thread by the location manager while recording.
    func add(location: CLLocation) {
        // CLLocation carries a wall-clock time; move it onto the uptime clock the other files use.
        let uptime = ProcessInfo.processInfo.systemUptime - Date().timeIntervalSince(location.timestamp)
        gpsQueue.async { self.gps?.add(location: location, uptime: uptime) }
    }

    // MARK: Frames

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let stream = streams.first(where: { $0.output === output }) else { return }
        stream.count(delivered: 1)
        if let writer = stream.writer, !writer.append(sampleBuffer) {
            stream.count(dropped: 1)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        streams.first(where: { $0.output === output })?.count(dropped: 1)
    }

    static func intrinsics(_ buffer: CMSampleBuffer) -> (fx: String, fy: String, cx: String, cy: String) {
        guard let data = CMGetAttachment(buffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? Data,
              data.count >= MemoryLayout<matrix_float3x3>.size else { return ("", "", "", "") }
        let k = data.withUnsafeBytes { $0.loadUnaligned(as: matrix_float3x3.self) } // column-major
        return ("\(k.columns.0.x)", "\(k.columns.1.y)", "\(k.columns.2.x)", "\(k.columns.2.y)")
    }

    static func exif(_ buffer: CMSampleBuffer) -> (exposure: String, iso: String) {
        guard let exif = CMGetAttachment(buffer, key: kCGImagePropertyExifDictionary, attachmentModeOut: nil) as? [String: Any] else {
            return ("", "")
        }
        let exposure = (exif[kCGImagePropertyExifExposureTime as String] as? NSNumber).map { "\($0.doubleValue)" } ?? ""
        let iso = ((exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first).map { "\($0.doubleValue)" } ?? ""
        return (exposure, iso)
    }

    // MARK: Motion sensors (same imu.csv format as the ARKit mode)

    private func startIMU() {
        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 1.0 / 1200.0 // capped to the hardware rate (100 Hz measured)
            motion.startAccelerometerUpdates(to: imuQueue) { data, _ in
                guard let data = data else { return }
                self.latestAccel = (data.timestamp, simd_double3(data.acceleration.x, data.acceleration.y, data.acceleration.z))
                self.writeIMUIfPaired()
            }
        }
        if motion.isGyroAvailable {
            motion.gyroUpdateInterval = 1.0 / 1200.0
            motion.startGyroUpdates(to: imuQueue) { data, _ in
                guard let data = data else { return }
                self.latestGyro = (data.timestamp, simd_double3(data.rotationRate.x, data.rotationRate.y, data.rotationRate.z))
                self.writeIMUIfPaired()
            }
        }
    }

    private func stopIMU() {
        if motion.isAccelerometerActive { motion.stopAccelerometerUpdates() }
        if motion.isGyroActive { motion.stopGyroUpdates() }
        imuQueue.waitUntilAllOperationsAreFinished()
    }

    private func writeIMUIfPaired() {
        guard let a = latestAccel, let g = latestGyro else { return }
        imuLock.lock()
        imu?.add(timestamp: max(a.t, g.t), linear: a.v, angular: g.v)
        imuLock.unlock()
        latestAccel = nil
        latestGyro = nil
    }
}
