//
//  RecordSessionViewController.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/28/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//
//  RoadCapture changes (TeslaRender D-011): 4K30 / 1440p60 formats, focus pinned far, a Lock button
//  (white balance + short shutter), HDR off, optional LiDAR, GPS logging, a status line, and the
//  screen kept awake while this view is open.
//

import Foundation
import UIKit
import Metal
import ARKit
import CoreData
import CoreMotion
import CoreLocation

let FpsDividers: [Int] = [1, 2, 4, 12, 60]
let FpsUserDefaultsKey: String = "FPS"
let CaptureModeUserDefaultsKey: String = "CaptureMode"
let DepthUserDefaultsKey: String = "DepthEnabled"

/// The two recording formats D-011 asks for.
enum CaptureMode: Int, CaseIterable {
    case uhd30 = 0  // 3840x2160 at 30 fps (ARKit 6 4K mode)
    case hd60 = 1   // 1920x1440 at 60 fps (ARKit's default)

    var label: String {
        switch self {
        case .uhd30: return "4K30"
        case .hd60: return "1440p60"
        }
    }

    /// The matching ARKit format, or nil when this phone doesn't offer it.
    func videoFormat() -> ARConfiguration.VideoFormat? {
        switch self {
        case .uhd30:
            if #available(iOS 16.0, *) {
                return ARWorldTrackingConfiguration.recommendedVideoFormatFor4KResolution
            }
            return nil
        case .hd60:
            return ARWorldTrackingConfiguration.supportedVideoFormats.first {
                $0.imageResolution == CGSize(width: 1920, height: 1440) && $0.framesPerSecond == 60
            }
        }
    }
}

class MetalView : UIView {
    override class var layerClass: AnyClass {
        get {
            return CAMetalLayer.self
        }
    }
    override var layer: CAMetalLayer {
        return super.layer as! CAMetalLayer
    }
}

class RecordSessionViewController : UIViewController, ARSessionDelegate, CLLocationManagerDelegate {
    private var unsupported: Bool = false
    private var arConfiguration: ARWorldTrackingConfiguration?
    private let session = ARSession()
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    private var renderer: CameraRenderer?
    private var updateLabelTimer: Timer?
    private var statusTimer: Timer?
    private var startedRecording: Date?
    private var dataContext: NSManagedObjectContext!
    private var datasetEncoder: DatasetEncoder?
    private let imuOperationQueue = OperationQueue()
    private var chosenFpsSetting: Int = 0
    private var captureMode: CaptureMode = .uhd30
    private var depthEnabled: Bool = false
    private var cameraLocked: Bool = false
    private var pendingCameraSetup: Bool = false
    private var lastTracking: String = "starting"
    private var lastGpsAccuracy: Double?
    private let modeButton = UIButton(type: .system)
    private let lockButton = UIButton(type: .system)
    private let depthButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    @IBOutlet private var rgbView: MetalView!
    @IBOutlet private var depthView: MetalView!
    @IBOutlet private var recordButton: RecordButton!
    @IBOutlet private var timeLabel: UILabel!
    @IBOutlet weak var fpsButton: UIButton!
    var dismissFunction: Optional<() -> Void> = Optional.none

    func setDismissFunction(_ fn: Optional<() -> Void>) {
        self.dismissFunction = fn
    }
    override func viewWillAppear(_ animated: Bool) {
        self.chosenFpsSetting = UserDefaults.standard.integer(forKey: FpsUserDefaultsKey) % FpsDividers.count
        self.captureMode = CaptureMode(rawValue: UserDefaults.standard.integer(forKey: CaptureModeUserDefaultsKey)) ?? .uhd30
        self.depthEnabled = UserDefaults.standard.bool(forKey: DepthUserDefaultsKey)
        updateFpsSetting()
        updateControls()
    }

    override func viewDidLoad() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        self.dataContext = appDelegate.persistentContainer.newBackgroundContext()
        self.renderer = CameraRenderer(rgbLayer: rgbView.layer, depthLayer: depthView.layer)
        // Road capture: start on the camera image, not the depth view.
        renderer?.renderMode = .rgb
        rgbView.isHidden = false
        depthView.isHidden = true

        depthView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))
        rgbView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(viewTapped)))

        setViewProperties()
        setUpControls()
        session.delegate = self

        recordButton.setCallback { (recording: Bool) in
            self.toggleRecording(recording)
        }
        fpsButton.layer.masksToBounds = true
        fpsButton.layer.cornerRadius = 12.0

        imuOperationQueue.qualityOfService = .userInitiated

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
    }

    override func viewDidDisappear(_ animated: Bool) {
        session.pause();
    }

    override func viewWillDisappear(_ animated: Bool) {
        updateLabelTimer?.invalidate()
        statusTimer?.invalidate()
        statusTimer = nil
        locationManager.stopUpdatingLocation()
        UIApplication.shared.isIdleTimerDisabled = false
        datasetEncoder = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        // A screen lock mid-drive would pause ARKit and break the recording.
        UIApplication.shared.isIdleTimerDisabled = true
        locationManager.startUpdatingLocation()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        startSession()
    }

    private func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("AR is not supported.")
            unsupported = true
            return
        }
        let config = ARWorldTrackingConfiguration()
        if let format = captureMode.videoFormat() {
            config.videoFormat = format
        } else if captureMode == .uhd30, let format = CaptureMode.hd60.videoFormat() {
            captureMode = .hd60 // no 4K on this phone
            config.videoFormat = format
        }
        config.isAutoFocusEnabled = false // fixed focus; pinned far once frames arrive
        if #available(iOS 16.0, *) {
            config.videoHDRAllowed = false // HDR tone mapping changes colours frame to frame
        }
        if depthEnabled && ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        arConfiguration = config
        cameraLocked = false
        pendingCameraSetup = true
        session.run(config, options: [.resetTracking])
        applyPreviewAspect(config.videoFormat.imageResolution)
        updateFpsSetting()
        updateControls()
    }

    private func restartSession() {
        session.pause()
        startSession()
    }

    /// Focus at the far end of the lens range: the road is metres to kilometres away.
    private func focusFar() {
        guard #available(iOS 16.0, *) else { return }
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }
        do {
            try device.lockForConfiguration()
            if device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: 1.0, completionHandler: nil)
            }
            device.unlockForConfiguration()
        } catch let error {
            print("Could not set focus. \(error.localizedDescription)")
        }
    }

    /// Lock: white balance fixed and a shutter of at most 1/1000 s (ISO raised to keep the
    /// brightness) against motion blur. Unlock returns to continuous auto exposure and white balance.
    private func applyCameraLock(_ locked: Bool) {
        guard #available(iOS 16.0, *) else { return }
        guard let device = ARWorldTrackingConfiguration.configurableCaptureDeviceForPrimaryCamera else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if locked {
                if device.isWhiteBalanceModeSupported(.locked) {
                    device.whiteBalanceMode = .locked
                }
                if device.isExposureModeSupported(.custom) {
                    let format = device.activeFormat
                    let current = device.exposureDuration.seconds
                    let target = max(min(current.isFinite && current > 0 ? current : 1.0 / 1000.0, 1.0 / 1000.0),
                                     format.minExposureDuration.seconds)
                    let gain = current.isFinite && current > 0 ? Float(current / target) : 1
                    let iso = min(max(device.iso * gain, format.minISO), format.maxISO)
                    device.setExposureModeCustom(duration: CMTime(seconds: target, preferredTimescale: 1_000_000),
                                                 iso: iso, completionHandler: nil)
                } else if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
            } else {
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
        } catch let error {
            print("Could not lock the camera. \(error.localizedDescription)")
        }
    }

    private func startRawIMU() {
        if self.motionManager.isAccelerometerAvailable {
            self.motionManager.accelerometerUpdateInterval = 1.0 / 1200.0 // Set update rate
            self.motionManager.startAccelerometerUpdates(to: imuOperationQueue) { (data, error) in
                guard let data = data else {
                    if let error = error {
                        print("Error retrieving accelerometer data: \(error.localizedDescription)")
                    }
                    return
                }
                self.datasetEncoder?.addRawAccelerometer(data: data)
            }
        } else {
            print("Accelerometer not available on this device.")
        }

        if self.motionManager.isGyroAvailable {
            self.motionManager.gyroUpdateInterval = 1.0 / 1200.0 // Set update rate
            self.motionManager.startGyroUpdates(to: imuOperationQueue) { (data, error) in
                guard let data = data else {
                    if let error = error {
                        print("Error retrieving gyroscope data: \(error.localizedDescription)")
                    }
                    return
                }
                self.datasetEncoder?.addRawGyroscope(data: data)
            }
        } else {
            print("Gyroscope not available on this device.")
        }
    }

    private func stopRawIMU() {
        if self.motionManager.isAccelerometerActive {
            self.motionManager.stopAccelerometerUpdates()
            print("Stopped accelerometer updates.")
        }
        if self.motionManager.isGyroActive {
            self.motionManager.stopGyroUpdates()
            print("Stopped gyroscope updates.")
        }
    }

    private func toggleRecording(_ recording: Bool) {
        if unsupported {
            showUnsupportedAlert()
            return
        }
        if recording && self.startedRecording == nil {
            startRecording()
        } else if self.startedRecording != nil && !recording {
            stopRecording()
        } else {
            print("This should not happen. We are either not recording and want to stop, or we are recording and want to start.")
        }
    }

    private func startRecording() {
        guard let config = arConfiguration else { return }
        self.startedRecording = Date()
        updateTime()
        updateLabelTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.updateTime()
        }
        datasetEncoder = DatasetEncoder(arConfiguration: config,
                                        fpsDivider: FpsDividers[chosenFpsSetting],
                                        depthEnabled: config.frameSemantics.contains(.sceneDepth),
                                        captureInfo: captureInfo())
        startRawIMU()
        updateControls()
    }

    private func stopRecording() {
        guard let started = self.startedRecording else {
            print("Hasn't started recording. Something is wrong.")
            return
        }
        startedRecording = nil
        updateLabelTimer?.invalidate()
        updateLabelTimer = nil
        // Stop IMU updates
        stopRawIMU()
        datasetEncoder?.wrapUp()
        if let encoder = datasetEncoder {
            switch encoder.status {
                case .allGood:
                    saveRecording(started, encoder)
                case .videoEncodingError:
                    showError()
                case .directoryCreationError:
                    showError()
            }
        } else {
            print("No dataset encoder. Something is wrong.")
        }
        updateControls()
        self.dismissFunction?()
    }

    private func captureInfo() -> [String: Any] {
        return [
            "app": "RoadCapture (fork of Stray Scanner ec3e1dc)",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "device_model": DatasetEncoder.deviceModel(),
            "ios_version": UIDevice.current.systemVersion,
            "capture_mode": captureMode.label,
            "fps_divider": FpsDividers[chosenFpsSetting],
            "camera_locked_at_start": cameraLocked,
            "clock": "All CSV timestamps are seconds on the system uptime clock (ARFrame.timestamp, CoreMotion, ProcessInfo.systemUptime).",
        ]
    }

    private func saveRecording(_ started: Date, _ encoder: DatasetEncoder) {
        let sessionCount = countSessions()

        let duration = Date().timeIntervalSince(started)
        let entity = NSEntityDescription.entity(forEntityName: "Recording", in: self.dataContext)!
        let recording: Recording = Recording(entity: entity, insertInto: self.dataContext)
        recording.setValue(datasetEncoder!.id, forKey: "id")
        recording.setValue(duration, forKey: "duration")
        recording.setValue(started, forKey: "createdAt")
        recording.setValue("Recording \(sessionCount)", forKey: "name")
        recording.setValue(datasetEncoder!.rgbFilePath.relativeString, forKey: "rgbFilePath")
        recording.setValue(datasetEncoder!.depthFilePath.relativeString, forKey: "depthFilePath")
        do {
            try self.dataContext.save()
        } catch let error as NSError {
            print("Could not save recording. \(error), \(error.userInfo)")
        }
    }

    private func showError() {
        let controller = UIAlertController(title: "Error",
            message: "Something went wrong when encoding video. This should not have happened. You might want to file a bug report.",
            preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default Action"), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(controller, animated: true, completion: nil)
    }

    private func updateTime() {
        guard let started = self.startedRecording else { return }
        let seconds = Date().timeIntervalSince(started)
        let minutes: Int = Int(floor(seconds / 60).truncatingRemainder(dividingBy: 60))
        let hours: Int = Int(floor(seconds / 3600))
        let roundSeconds: Int = Int(floor(seconds.truncatingRemainder(dividingBy: 60)))
        self.timeLabel.text = String(format: "%02d:%02d:%02d", hours, minutes, roundSeconds)
    }

    private func updateStatus() {
        let thermalState = ProcessInfo.processInfo.thermalState.rawValue
        let thermal = ["nominal", "fair", "serious", "critical"][min(3, max(0, thermalState))]
        let gps = lastGpsAccuracy.map { $0 >= 0 ? String(format: "±%.0f m", $0) : "no fix" } ?? "waiting"
        var format = "–"
        if let video = arConfiguration?.videoFormat {
            format = "\(Int(video.imageResolution.width))x\(Int(video.imageResolution.height))@\(video.framesPerSecond)"
        }
        statusLabel.text = " \(format) · tracking \(lastTracking) \n GPS \(gps) · heat \(thermal) "
        statusLabel.textColor = thermalState >= 2 ? .systemOrange : .white
    }

    @objc func viewTapped() {
        // Without LiDAR depth there is nothing to show in the depth view.
        guard arConfiguration?.frameSemantics.contains(.sceneDepth) ?? false else { return }
        switch renderer!.renderMode {
            case .depth:
                renderer!.renderMode = RenderMode.rgb
                rgbView.isHidden = false
                depthView.isHidden = true
            case .rgb:
                renderer!.renderMode = RenderMode.depth
                depthView.isHidden = false
                rgbView.isHidden = true
        }
    }

    @IBAction func fpsButtonTapped() {
        chosenFpsSetting = (chosenFpsSetting + 1) % FpsDividers.count
        updateFpsSetting()
        UserDefaults.standard.set(chosenFpsSetting, forKey: FpsUserDefaultsKey)
    }

    @objc private func modeButtonTapped() {
        guard startedRecording == nil else { return }
        captureMode = captureMode == .uhd30 ? .hd60 : .uhd30
        UserDefaults.standard.set(captureMode.rawValue, forKey: CaptureModeUserDefaultsKey)
        restartSession()
    }

    @objc private func lockButtonTapped() {
        cameraLocked.toggle()
        applyCameraLock(cameraLocked)
        updateControls()
    }

    @objc private func depthButtonTapped() {
        guard startedRecording == nil else { return }
        depthEnabled.toggle()
        UserDefaults.standard.set(depthEnabled, forKey: DepthUserDefaultsKey)
        if !depthEnabled {
            renderer?.renderMode = .rgb
            rgbView.isHidden = false
            depthView.isHidden = true
        }
        restartSession()
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if pendingCameraSetup {
            // Camera settings stick only once ARKit's capture session is running.
            pendingCameraSetup = false
            focusFar()
            if cameraLocked {
                applyCameraLock(true)
            }
        }
        let tracking = FrameMetadataEncoder.describe(frame.camera.trackingState)
        lastTracking = tracking.reason.isEmpty ? tracking.state : "\(tracking.state): \(tracking.reason)"
        self.renderer!.render(frame: frame)
        if startedRecording != nil {
            if let encoder = datasetEncoder {
                encoder.add(frame: frame, cameraLocked: cameraLocked)
            } else {
                print("There is no video encoder. That can't be good.")
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        lastTracking = "failed: \(error.localizedDescription)"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            lastGpsAccuracy = location.horizontalAccuracy
            if startedRecording != nil {
                datasetEncoder?.add(location: location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    private func setViewProperties() {
        self.view.backgroundColor = UIColor(named: "BackgroundColor")
    }

    private func setUpControls() {
        let buttons: [(UIButton, Selector)] = [
            (modeButton, #selector(modeButtonTapped)),
            (lockButton, #selector(lockButtonTapped)),
            (depthButton, #selector(depthButtonTapped)),
        ]
        for (button, action) in buttons {
            button.backgroundColor = UIColor(named: "DarkColor")
            button.setTitleColor(UIColor(named: "LightColor"), for: .normal)
            button.setTitleColor(.gray, for: .disabled)
            button.titleLabel?.font = UIFont(name: "CourierNewPSMT", size: 17)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            button.layer.cornerRadius = 12.0
            button.layer.masksToBounds = true
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        let stack = UIStackView(arrangedSubviews: buttons.map { $0.0 })
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont(name: "CourierNewPSMT", size: 13) ?? UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor(white: 0.0, alpha: 0.55)
        statusLabel.numberOfLines = 0
        view.addSubview(statusLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: rgbView.bottomAnchor, constant: -8),
        ])
    }

    private func updateControls() {
        let recording = startedRecording != nil
        modeButton.setTitle(captureMode.label, for: .normal)
        lockButton.setTitle(cameraLocked ? "Locked" : "Lock", for: .normal)
        depthButton.setTitle(depthEnabled ? "LiDAR on" : "LiDAR off", for: .normal)
        depthButton.isHidden = !ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        modeButton.isEnabled = !recording
        depthButton.isEnabled = !recording
        fpsButton?.isEnabled = !recording
    }

    /// The XIB fixes the preview at 3:4 (ARKit's 1920x1440); 4K is 16:9, so match the active format.
    private func applyPreviewAspect(_ resolution: CGSize) {
        guard resolution.width > 0 else { return }
        for metalView in [rgbView!, depthView!] {
            metalView.constraints
                .filter { $0.firstItem === metalView && $0.secondItem === metalView && $0.firstAttribute == .width && $0.secondAttribute == .height }
                .forEach { $0.isActive = false }
            metalView.widthAnchor.constraint(equalTo: metalView.heightAnchor, multiplier: resolution.height / resolution.width).isActive = true
        }
    }

    private func updateFpsSetting() {
        let cameraFps = arConfiguration?.videoFormat.framesPerSecond ?? 60
        let fps = max(1, cameraFps / FpsDividers[chosenFpsSetting])
        fpsButton?.setTitle("\(fps) fps", for: UIControl.State.normal)
    }

    private func showUnsupportedAlert() {
        let alert = UIAlertController(title: "Unsupported device", message: "This device doesn't seem to have the required level of ARKit support.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            self.dismissFunction?()
        }))
        self.present(alert, animated: true)
    }

    private func countSessions() -> Int {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return 0 }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Recording")
        do {
            let fetched: [NSManagedObject] = try appDelegate.persistentContainer.viewContext.fetch(request)
            return fetched.count
        } catch let error {
            print("Could not fetch sessions for counting. \(error.localizedDescription)")
        }
        return 0
    }
}
