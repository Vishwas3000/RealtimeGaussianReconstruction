//
//  CameraProbe.swift
//  RoadCapture (TeslaRender D-012, step 1)
//
//  Finds out what this iPhone's rear cameras can do together, so the multi-lens mode is built on facts:
//  which lens combinations AVFoundation allows, the largest 30 fps format each combination fits in
//  (hardware cost <= 1), its heat cost, whether the lenses' frames line up in time, and the factory
//  calibration between lenses. Writes Documents/probe/camera_probe_<time>.json.
//

import AVFoundation
import ARKit
import SwiftUI
import simd

final class CameraProbe {
    static var autoRan = false   // the "-probe" launch argument runs it once
    private let probeQueue = DispatchQueue(label: "cameraProbe")
    private let runSeconds: TimeInterval = 3

    static let deviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera, .builtInDualCamera,
        .builtInDualWideCamera, .builtInTripleCamera, .builtInLiDARDepthCamera, .builtInTrueDepthCamera,
    ]

    func run(deviceModel: String, iosVersion: String, progress: @escaping (String) -> Void,
             completion: @escaping (_ file: URL?, _ summary: String) -> Void) {
        probeQueue.async {
            let (report, summary) = self.probe(deviceModel: deviceModel, iosVersion: iosVersion) { text in
                DispatchQueue.main.async { progress(text) }
            }
            let file = CameraProbe.save(report)
            let saved = file.map { "\nSaved to probe/\($0.lastPathComponent)" } ?? "\nCould not save the report."
            DispatchQueue.main.async { completion(file, summary + saved) }
        }
    }

    private func probe(deviceModel: String, iosVersion: String, progress: (String) -> Void) -> ([String: Any], String) {
        var report: [String: Any] = [
            "probe_version": 1,
            "time": ISO8601DateFormatter().string(from: Date()),
            "device_model": deviceModel,
            "ios_version": iosVersion,
            "multicam_supported": AVCaptureMultiCamSession.isMultiCamSupported,
            "camera_authorized": AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
            "thermal_state_start": ProcessInfo.processInfo.thermalState.rawValue,
        ]
        var lines: [String] = ["\(deviceModel), iOS \(iosVersion)"]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: CameraProbe.deviceTypes, mediaType: .video, position: .unspecified)
        let devices = discovery.devices
        report["devices"] = devices.map(CameraProbe.describe)
        lines.append("Cameras: " + devices.map(CameraProbe.name).joined(separator: ", "))
        lines.append("Multi-camera: " + (AVCaptureMultiCamSession.isMultiCamSupported ? "supported" : "NOT supported"))

        let sets = discovery.supportedMultiCamDeviceSets
        report["multicam_sets"] = sets.map { $0.map(CameraProbe.name).sorted() }
        let rearSets = sets.filter { $0.allSatisfy { $0.position == .back } }.map { Array($0) }
        lines.append("Rear lens sets iOS allows together:")
        lines += rearSets.map { "  " + $0.map(CameraProbe.name).sorted().joined(separator: " + ") }

        let extrinsics = CameraProbe.extrinsics(devices)
        report["extrinsics"] = extrinsics
        for e in extrinsics where (e["from"] as? String ?? "") < (e["to"] as? String ?? "") {
            lines.append(String(format: "Factory baseline %@ → %@: %.1f mm", e["from"] as? String ?? "", e["to"] as? String ?? "",
                                e["baseline_mm"] as? Double ?? -1))
        }

        // Every allowed rear set, plus each combined camera alone: its lenses stream in hardware sync.
        var configs = rearSets
        for d in devices where d.position == .back && d.constituentDevices.count > 1 && d.deviceType != .builtInLiDARDepthCamera
            && !configs.contains([d]) {
            configs.append([d])
        }
        var results: [[String: Any]] = []
        if AVCaptureMultiCamSession.isMultiCamSupported {
            lines.append("Tested (largest 30 fps format that fits; frames run for \(Int(runSeconds)) s):")
            for (i, config) in configs.enumerated() {
                let label = config.map(CameraProbe.name).sorted().joined(separator: " + ")
                progress("Testing \(label) (\(i + 1) of \(configs.count))…")
                let result = test(config)
                results.append(result)
                lines.append("  " + CameraProbe.summaryLine(label: label, result: result))
            }
        }
        report["configs"] = results
        report["arkit"] = CameraProbe.arkitFormats()
        report["thermal_state_end"] = ProcessInfo.processInfo.thermalState.rawValue
        return (report, lines.joined(separator: "\n"))
    }

    /// Builds a multi-camera session for these devices, fits the formats under the hardware budget, then
    /// streams for a few seconds to measure the real frame rates and the time offsets between lenses.
    private func test(_ devices: [AVCaptureDevice]) -> [String: Any] {
        var result: [String: Any] = ["devices": devices.map(CameraProbe.name).sorted()]
        let session = AVCaptureMultiCamSession()
        let collector = FrameCollector()
        var intrinsics: [String: Bool] = [:]
        func fail(_ message: String) -> [String: Any] {
            session.commitConfiguration()
            result["error"] = message
            return result
        }

        session.beginConfiguration()
        for device in devices {
            guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                return fail("cannot add \(CameraProbe.name(device))")
            }
            session.addInputWithNoConnections(input)
            // A combined camera streams each of its lenses through its own port; the LiDAR camera is one image stream.
            let lenses = device.constituentDevices.count > 1 && device.deviceType != .builtInLiDARDepthCamera
                ? device.constituentDevices : [device]
            for lens in lenses {
                let port = lenses.count == 1
                    ? input.ports.first { $0.mediaType == .video }
                    : input.ports(for: .video, sourceDeviceType: lens.deviceType, sourceDevicePosition: lens.position).first
                guard let videoPort = port else { return fail("no video port for \(CameraProbe.name(lens))") }
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(collector, queue: collector.queue)
                guard session.canAddOutput(output) else { return fail("cannot add an output for \(CameraProbe.name(lens))") }
                session.addOutputWithNoConnections(output)
                let connection = AVCaptureConnection(inputPorts: [videoPort], output: output)
                guard session.canAddConnection(connection) else { return fail("cannot connect \(CameraProbe.name(lens))") }
                session.addConnection(connection)
                collector.register(output, name: CameraProbe.name(lens))
                intrinsics[CameraProbe.name(lens)] = connection.isCameraIntrinsicMatrixDeliverySupported
            }
            if device.deviceType == .builtInLiDARDepthCamera, let depthPort = input.ports.first(where: { $0.mediaType == .depthData }) {
                let depthOutput = AVCaptureDepthDataOutput()
                depthOutput.alwaysDiscardsLateDepthData = true
                depthOutput.setDelegate(collector, callbackQueue: collector.queue)
                if session.canAddOutput(depthOutput) {
                    session.addOutputWithNoConnections(depthOutput)
                    let connection = AVCaptureConnection(inputPorts: [depthPort], output: depthOutput)
                    if session.canAddConnection(connection) {
                        session.addConnection(connection)
                        collector.hasDepth = true
                    }
                }
            }
        }
        result["intrinsics_per_frame"] = intrinsics

        // Largest multi-camera 30 fps format per device; shrink the biggest until the hardware cost fits.
        let candidates = devices.map(CameraProbe.multicamFormats)
        if let k = candidates.firstIndex(where: { $0.isEmpty }) {
            return fail("no multi-camera 30 fps format for \(CameraProbe.name(devices[k]))")
        }
        var choice = devices.map { _ in 0 }
        func apply() {
            for (k, device) in devices.enumerated() { CameraProbe.setFormat(device, candidates[k][choice[k]]) }
        }
        apply()
        session.commitConfiguration()
        while session.hardwareCost > 1.0 {
            let shrinkable = devices.indices.filter { choice[$0] + 1 < candidates[$0].count }
            guard let k = shrinkable.max(by: { CameraProbe.pixels(candidates[$0][choice[$0]]) < CameraProbe.pixels(candidates[$1][choice[$1]]) })
            else { break }
            choice[k] += 1
            session.beginConfiguration()
            apply()
            session.commitConfiguration()
        }
        result["hardware_cost"] = Double(session.hardwareCost)
        result["system_pressure_cost"] = Double(session.systemPressureCost)
        result["fits"] = session.hardwareCost <= 1.0
        var formats: [String: String] = [:]
        for (k, device) in devices.enumerated() {
            formats[CameraProbe.name(device)] = CameraProbe.formatLabel(candidates[k][choice[k]])
        }
        result["formats"] = formats
        if session.hardwareCost <= 1.0 {
            session.startRunning()
            Thread.sleep(forTimeInterval: runSeconds)
            let pressure = devices.first.map { CameraProbe.levelName($0.systemPressureState.level) } ?? ""
            session.stopRunning()
            result["run"] = collector.summary(seconds: runSeconds, pressure: pressure)
        }
        return result
    }

    // MARK: Descriptions

    static func name(_ d: AVCaptureDevice) -> String {
        switch d.deviceType {
        case .builtInWideAngleCamera: return d.position == .front ? "front" : "wide"
        case .builtInUltraWideCamera: return "ultraWide"
        case .builtInTelephotoCamera: return "tele"
        case .builtInDualCamera: return "dual"
        case .builtInDualWideCamera: return "dualWide"
        case .builtInTripleCamera: return "triple"
        case .builtInLiDARDepthCamera: return "lidar"
        case .builtInTrueDepthCamera: return "trueDepth"
        default: return d.deviceType.rawValue
        }
    }

    static func describe(_ d: AVCaptureDevice) -> [String: Any] {
        return [
            "name": name(d),
            "type": d.deviceType.rawValue,
            "position": d.position == .back ? "back" : (d.position == .front ? "front" : "unspecified"),
            "constituents": d.constituentDevices.map(name),
            "gdc_supported": d.isGeometricDistortionCorrectionSupported,
            "lens_position_lock": d.isLockingFocusWithCustomLensPositionSupported,
            "formats": d.formats.map(describeFormat),
        ]
    }

    static func describeFormat(_ f: AVCaptureDevice.Format) -> [String: Any] {
        let dims = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
        var d: [String: Any] = [
            "w": Int(dims.width), "h": Int(dims.height),
            "pixel_format": fourCC(CMFormatDescriptionGetMediaSubType(f.formatDescription)),
            "fps": f.videoSupportedFrameRateRanges.map { [$0.minFrameRate, $0.maxFrameRate] },
            "multicam": f.isMultiCamSupported,
            "binned": f.isVideoBinned,
            "fov": Double(f.videoFieldOfView),
            "iso": [Double(f.minISO), Double(f.maxISO)],
            "exposure_s": [f.minExposureDuration.seconds, f.maxExposureDuration.seconds],
            "spatial_video": f.isSpatialVideoCaptureSupported,
        ]
        let depth = f.supportedDepthDataFormats.map { df -> [String: Any] in
            let dd = CMVideoFormatDescriptionGetDimensions(df.formatDescription)
            return ["w": Int(dd.width), "h": Int(dd.height),
                    "pixel_format": fourCC(CMFormatDescriptionGetMediaSubType(df.formatDescription)),
                    "fps": df.videoSupportedFrameRateRanges.map { [$0.minFrameRate, $0.maxFrameRate] }]
        }
        if !depth.isEmpty { d["depth_formats"] = depth }
        return d
    }

    /// 8-bit 4:2:0 formats that run in a multi-camera session at 30 fps, largest first, one per size.
    static func multicamFormats(_ device: AVCaptureDevice) -> [AVCaptureDevice.Format] {
        var seen = Set<String>()
        return device.formats
            .filter { f in
                f.isMultiCamSupported
                    && ["420v", "420f"].contains(fourCC(CMFormatDescriptionGetMediaSubType(f.formatDescription)))
                    && f.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
                    && (device.deviceType != .builtInLiDARDepthCamera || !f.supportedDepthDataFormats.isEmpty)
            }
            .sorted { pixels($0) > pixels($1) }
            .filter { seen.insert(formatLabel($0)).inserted }
    }

    static func setFormat(_ device: AVCaptureDevice, _ format: AVCaptureDevice.Format) {
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            let thirty = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = thirty
            device.activeVideoMaxFrameDuration = thirty
            if device.deviceType == .builtInLiDARDepthCamera,
               let depth = format.supportedDepthDataFormats.max(by: { pixels($0) < pixels($1) }) {
                device.activeDepthDataFormat = depth
            }
            device.unlockForConfiguration()
        } catch {
            print("probe: cannot configure \(name(device)): \(error.localizedDescription)")
        }
    }

    static func pixels(_ f: AVCaptureDevice.Format) -> Int {
        let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
        return Int(d.width) * Int(d.height)
    }

    static func formatLabel(_ f: AVCaptureDevice.Format) -> String {
        let d = CMVideoFormatDescriptionGetDimensions(f.formatDescription)
        return "\(d.width)x\(d.height)"
    }

    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(bytes: bytes, encoding: .ascii) ?? "\(code)"
    }

    static func levelName(_ level: AVCaptureDevice.SystemPressureState.Level) -> String {
        switch level {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        case .shutdown: return "shutdown"
        default: return level.rawValue
        }
    }

    /// Factory calibration between each pair of rear lenses: rotation and translation (mm).
    static func extrinsics(_ devices: [AVCaptureDevice]) -> [[String: Any]] {
        let lenses = devices.filter {
            $0.position == .back && [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera].contains($0.deviceType)
        }
        var out: [[String: Any]] = []
        for a in lenses {
            for b in lenses where a !== b {
                guard let data = AVCaptureDevice.extrinsicMatrix(from: a, to: b),
                      data.count >= MemoryLayout<matrix_float4x3>.size else { continue }
                let m = data.withUnsafeBytes { $0.loadUnaligned(as: matrix_float4x3.self) }
                let columns = [m.columns.0, m.columns.1, m.columns.2, m.columns.3]
                let t = m.columns.3
                out.append([
                    "from": name(a), "to": name(b),
                    "matrix_columns": columns.map { [Double($0.x), Double($0.y), Double($0.z)] },
                    "translation_mm": [Double(t.x), Double(t.y), Double(t.z)],
                    "baseline_mm": Double(simd_length(t)),
                ])
            }
        }
        return out
    }

    static func arkitFormats() -> [String: Any] {
        var out: [String: Any] = [
            "scene_depth_supported": ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth),
            "formats": ARWorldTrackingConfiguration.supportedVideoFormats.map { f -> [String: Any] in
                ["w": Int(f.imageResolution.width), "h": Int(f.imageResolution.height), "fps": f.framesPerSecond,
                 "device": f.captureDeviceType.rawValue, "hdr": f.isVideoHDRSupported]
            },
        ]
        if let k = ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution {
            out["recommended_4k"] = "\(Int(k.imageResolution.width))x\(Int(k.imageResolution.height))@\(k.framesPerSecond)"
        }
        return out
    }

    static func summaryLine(label: String, result: [String: Any]) -> String {
        if let error = result["error"] as? String { return "\(label): \(error)" }
        let formats = (result["formats"] as? [String: String] ?? [:]).sorted { $0.key < $1.key }
            .map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        var line = "\(label): \(formats)" + String(format: "; cost %.2f, heat %.2f",
                                                    result["hardware_cost"] as? Double ?? -1,
                                                    result["system_pressure_cost"] as? Double ?? -1)
        if let run = result["run"] as? [String: Any] {
            let fps = (run["fps"] as? [String: Double] ?? [:]).sorted { $0.key < $1.key }
                .map { "\($0.key) " + String(format: "%.0f", $0.value) }.joined(separator: ", ")
            line += "; ran \(fps) fps"
            if let offsets = run["median_offset_ms"] as? [String: Double], !offsets.isEmpty {
                line += "; offset " + offsets.sorted { $0.key < $1.key }.map { String(format: "%.1f", $0.value) }.joined(separator: "/") + " ms"
            }
            if let depthFps = run["depth_fps"] as? Double { line += String(format: "; depth %.0f fps", depthFps) }
        } else if result["fits"] as? Bool == false {
            line += "; does NOT fit even at the smallest format"
        }
        return line
    }

    static func save(_ report: [String: Any]) -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("probe", isDirectory: true)
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        let url = directory.appendingPathComponent("camera_probe_\(stamp.string(from: Date())).json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
            return url
        } catch {
            print("probe: could not save. \(error.localizedDescription)")
            return nil
        }
    }
}

/// Collects frame timestamps per lens (and depth frames) during a probe run.
final class FrameCollector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    let queue = DispatchQueue(label: "probeFrames")
    var hasDepth = false
    private var names: [ObjectIdentifier: String] = [:]
    private var order: [String] = []
    private var times: [String: [Double]] = [:]
    private var depthFrames = 0

    func register(_ output: AVCaptureOutput, name: String) {
        names[ObjectIdentifier(output)] = name
        order.append(name)
        times[name] = []
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let name = names[ObjectIdentifier(output)] else { return }
        times[name, default: []].append(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
    }

    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime,
                         connection: AVCaptureConnection) {
        depthFrames += 1
    }

    /// Frame rate per lens, and the median gap between each lens's frames and the first lens's nearest frame:
    /// about 0 ms means hardware-synchronised; a steady few ms means free-running.
    func summary(seconds: Double, pressure: String) -> [String: Any] {
        return queue.sync {
            var fps: [String: Double] = [:]
            for (name, t) in times {
                if t.count > 1, let first = t.first, let last = t.last, last > first {
                    fps[name] = Double(t.count - 1) / (last - first)
                } else {
                    fps[name] = 0
                }
            }
            var offsets: [String: Double] = [:]
            if let reference = order.first, let referenceTimes = times[reference], referenceTimes.count > 2 {
                for name in order.dropFirst() {
                    guard let other = times[name], !other.isEmpty else { continue }
                    let gaps = referenceTimes.map { t in other.map { abs($0 - t) }.min() ?? 0 }.sorted()
                    offsets["\(reference)-\(name)"] = gaps[gaps.count / 2] * 1000
                }
            }
            var s: [String: Any] = ["seconds": seconds, "fps": fps, "median_offset_ms": offsets, "pressure": pressure,
                                    "frames": times.mapValues { $0.count }]
            if hasDepth { s["depth_fps"] = Double(depthFrames) / seconds }
            return s
        }
    }
}

struct ProbeView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var status = "Starting…"
    @State private var summary: String?
    @State private var started = false
    private let probe = CameraProbe()

    var body: some View {
        NavigationView {
            ScrollView {
                if let summary = summary {
                    Text(summary)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(status).font(.callout).multilineTextAlignment(.center)
                        Text("Keep the app open: this takes about a minute.").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Camera probe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }.disabled(summary == nil)
                }
            }
        }
        .interactiveDismissDisabled(summary == nil)
        .onAppear {
            guard !started else { return }
            started = true
            UIApplication.shared.isIdleTimerDisabled = true
            probe.run(deviceModel: DatasetEncoder.deviceModel(), iosVersion: UIDevice.current.systemVersion,
                      progress: { status = $0 }) { _, text in
                summary = text
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
}
