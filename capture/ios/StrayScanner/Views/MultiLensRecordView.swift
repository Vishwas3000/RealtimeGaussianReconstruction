//
//  MultiLensRecordView.swift
//  RoadCapture (TeslaRender D-014)
//
//  The multi-lens recording screen: preview of the wide lens, preset (2 lenses at 4K or all 3 at 1080p),
//  Lock, a live status line, and Record. Recordings appear in the Recordings list like ARKit ones.
//

import SwiftUI
import AVFoundation
import CoreLocation
import CoreData

final class MultiLensModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    let recorder = MultiCamRecorder()
    @Published var preset: MultiLensPreset
    @Published var recording = false
    @Published var busy = true
    @Published var locked = false
    @Published var status = "Starting the cameras…"
    @Published var error: String?
    private let location = CLLocationManager()
    private var timer: Timer?
    private var previous: [String: (delivered: Int, dropped: Int)] = [:]
    private var gpsAccuracy: Double?
    private var startedAt: Date?
    private let autoRecordSeconds: Double?
    private static let presetKey = "MultiLensPreset"

    init(autoRecordSeconds: Double? = nil) {
        self.autoRecordSeconds = autoRecordSeconds
        preset = MultiLensPreset(rawValue: UserDefaults.standard.integer(forKey: MultiLensModel.presetKey)) ?? .wideUltraWide4K
        super.init()
    }

    func appear() {
        UIApplication.shared.isIdleTimerDisabled = true // a screen lock mid-drive would stop the cameras
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        location.activityType = .automotiveNavigation
        location.distanceFilter = kCLDistanceFilterNone
        location.pausesLocationUpdatesAutomatically = false
        location.requestWhenInUseAuthorization()
        location.startUpdatingLocation()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        apply(preset)
    }

    func disappear() {
        if recording { stop() }
        timer?.invalidate()
        timer = nil
        location.stopUpdatingLocation()
        recorder.stopPreview()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func apply(_ preset: MultiLensPreset) {
        UserDefaults.standard.set(preset.rawValue, forKey: MultiLensModel.presetKey)
        busy = true
        locked = false
        recorder.configure(preset) { [weak self] error in
            guard let self = self else { return }
            self.busy = false
            self.error = error
            if error == nil, let seconds = self.autoRecordSeconds, !self.recording {
                self.start()
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { if self.recording { self.stop() } }
            }
        }
    }

    func toggleLock() {
        locked.toggle()
        recorder.setLocked(locked)
    }

    func toggleRecord() {
        recording ? stop() : start()
    }

    private func start() {
        busy = true
        let info: [String: Any] = [
            "app": "RoadCapture (fork of Stray Scanner ec3e1dc)",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "device_model": DatasetEncoder.deviceModel(),
            "ios_version": UIDevice.current.systemVersion,
            "camera_locked_at_start": locked,
        ]
        recorder.startRecording(info: info) { [weak self] error in
            guard let self = self else { return }
            self.busy = false
            if let error = error {
                self.error = error
            } else {
                self.recording = true
                self.startedAt = Date()
            }
        }
    }

    private func stop() {
        busy = true
        // Strong self: leaving the screen mid-recording must still add the finished recording to the list.
        recorder.stopRecording { directory, duration in
            self.save(directory, duration)
            self.recording = false
            self.busy = false
            self.startedAt = nil
        }
    }

    /// Adds the recording to the Recordings list; its "rgb" file is the wide lens, for the thumbnail.
    private func save(_ directory: URL?, _ duration: TimeInterval) {
        guard let directory = directory, let app = UIApplication.shared.delegate as? AppDelegate else { return }
        let context = app.persistentContainer.viewContext
        guard let entity = NSEntityDescription.entity(forEntityName: "Recording", in: context) else { return }
        let count = (try? context.count(for: NSFetchRequest<NSManagedObject>(entityName: "Recording"))) ?? 0
        let recording = Recording(entity: entity, insertInto: context)
        recording.setValue(UUID(), forKey: "id")
        recording.setValue(duration, forKey: "duration")
        recording.setValue(startedAt ?? Date(), forKey: "createdAt")
        recording.setValue("Recording \(count)", forKey: "name")
        recording.setValue("\(directory.lastPathComponent)/\(recorder.lensNames.first ?? "wide").mp4", forKey: "rgbFilePath")
        recording.setValue("\(directory.lastPathComponent)/depth", forKey: "depthFilePath")
        do {
            try context.save()
        } catch {
            self.error = "Recorded, but couldn't add it to the list: \(error.localizedDescription)"
        }
    }

    private func tick() {
        var lenses: [String] = []
        var drops = 0
        for stream in recorder.streams {
            let now = stream.counts()
            let before = previous[stream.name] ?? (0, 0)
            lenses.append("\(stream.name) \(now.delivered - before.delivered)")
            drops += now.dropped
            previous[stream.name] = now
        }
        let thermal = ["nominal", "fair", "serious", "critical"][min(3, max(0, ProcessInfo.processInfo.thermalState.rawValue))]
        let gps = gpsAccuracy.map { $0 >= 0 ? String(format: "±%.0f m", $0) : "no fix" } ?? "waiting"
        var time = ""
        if let started = startedAt {
            let s = Int(Date().timeIntervalSince(started))
            time = String(format: "REC %02d:%02d · ", s / 60, s % 60)
        }
        status = "\(time)\(recorder.formatLabel) · fps: \(lenses.joined(separator: ", "))\n"
            + "dropped \(drops) · GPS \(gps) · heat \(thermal)"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            gpsAccuracy = location.horizontalAccuracy
            if recording { recorder.add(location: location) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

struct MultiLensRecordView: View {
    @StateObject private var model: MultiLensModel

    init(autoRecordSeconds: Double? = nil) {
        _model = StateObject(wrappedValue: MultiLensModel(autoRecordSeconds: autoRecordSeconds))
    }

    var body: some View {
        VStack(spacing: 12) {
            PreviewLayerView(layer: model.recorder.previewLayer)
                .aspectRatio(9.0 / 16.0, contentMode: .fit) // the 16:9 sensor image, shown upright in portrait
                .background(Color.black)
                .frame(maxHeight: 520)
            Text(model.status)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            if let error = model.error {
                Text(error).font(.caption).foregroundColor(Color("DangerColor")).padding(.horizontal)
            }
            HStack {
                Picker("Lenses", selection: $model.preset) {
                    ForEach(MultiLensPreset.allCases, id: \.self) { preset in
                        Text(preset.shortLabel).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(model.recording || model.busy)
                Button(model.locked ? "Locked" : "Lock") { model.toggleLock() }
                    .buttonStyle(.bordered)
                    .disabled(model.busy)
            }
            .padding(.horizontal)
            .onChange(of: model.preset) { _, preset in model.apply(preset) }
            Button(action: model.toggleRecord) {
                Text(model.recording ? "Stop" : "Record")
                    .font(.title3)
                    .frame(minWidth: 140)
                    .padding(.vertical, 14)
                    .background(model.recording ? Color("DangerColor") : Color("TextColor"))
                    .foregroundColor(Color("LightColor"))
                    .cornerRadius(30)
            }
            .disabled(model.busy)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .background(Color("BackgroundColor").ignoresSafeArea())
        .navigationBarTitle("Multi-lens")
        .onAppear { model.appear() }
        .onDisappear { model.disappear() }
    }
}

/// Hosts the recorder's preview layer.
struct PreviewLayerView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewHost {
        let view = PreviewHost()
        view.previewLayer = layer
        return view
    }

    func updateUIView(_ uiView: PreviewHost, context: Context) {}

    final class PreviewHost: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let previewLayer = previewLayer { layer.addSublayer(previewLayer) }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}
