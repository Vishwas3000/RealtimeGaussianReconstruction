//
//  SessionDetailView.swift
//  StrayScanner
//
//  Created by Kenneth Blomqvist on 12/30/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//
//  RoadCapture changes: a "Frames + depth" tab (camera frame and its LiDAR depth, scrubbable), the
//  recording's facts, and a player sized to the recording's aspect ratio.
//

import SwiftUI
import AVKit
import CoreData
import ImageIO

class SessionDetailViewModel: ObservableObject {
    private var dataContext: NSManagedObjectContext?

    init() {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        self.dataContext = appDelegate?.persistentContainer.viewContext
    }

    func title(recording: Recording) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        if let created = recording.createdAt {
            return dateFormatter.string(from: created)
        } else {
            return recording.name ?? "Recording"
        }
    }

    func delete(recording: Recording) {
        recording.deleteFiles()
        self.dataContext?.delete(recording)
        do {
            try self.dataContext?.save()
        } catch let error as NSError {
            print("Could not save recording. \(error), \(error.userInfo)")
        }
    }
}

struct SessionDetailView: View {
    @ObservedObject var viewModel = SessionDetailViewModel()
    var recording: Recording
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var showingShareSheet = false
    @State private var tempPackageURL: URL?
    @State private var isCreatingPackage = false
    @State private var player: AVPlayer?
    @State private var shareError: String?
    @State private var summary: RecordingSummary?
    @State private var tab = 0

    let defaultUrl = URL(fileURLWithPath: "")

    var body: some View {
        ZStack {
        Color("BackgroundColor")
            .edgesIgnoringSafeArea(.all)
        ScrollView {
        VStack(spacing: 16) {
            Picker("View", selection: $tab) {
                Text("Video").tag(0)
                Text((summary?.depthFrames ?? 0) > 0 ? "Frames + depth" : "Frames").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if tab == 0 {
                VideoPlayer(player: player ?? AVPlayer(url: defaultUrl))
                    .aspectRatio(summary?.aspect ?? 4.0 / 3.0, contentMode: .fit)
                    .onAppear {
                        if player == nil {
                            player = AVPlayer(url: recording.absoluteRgbPath() ?? defaultUrl)
                        }
                    }
            } else if let summary = summary, let directory = recording.directoryPath() {
                FrameViewer(directory: directory, summary: summary)
            } else {
                ProgressView()
            }

            if let summary = summary {
                RecordingFacts(summary: summary)
            }

            HStack(spacing: 20) {
                Button(action: shareItem) {
                    HStack {
                        if isCreatingPackage {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isCreatingPackage ? "Preparing..." : "Share")
                            .fixedSize()
                    }
                    .foregroundColor(isCreatingPackage ? .gray : .blue)
                    .frame(minWidth: 100)
                }
                .disabled(isCreatingPackage)

                Button(action: deleteItem) {
                    Text("Delete").foregroundColor(Color("DangerColor"))
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical)
        }
        .navigationBarTitle(viewModel.title(recording: recording))
        .background(Color("BackgroundColor"))
        .task {
            guard summary == nil, let directory = recording.directoryPath() else { return }
            summary = await Task.detached { RecordingSummary.load(from: directory) }.value
        }
        .sheet(isPresented: $showingShareSheet) {
            if let packageURL = tempPackageURL {
                ShareSheet(activityItems: [packageURL]) { activityType, completed, returnedItems, activityError in
                    DispatchQueue.main.async {
                        // Clean up temporary package after sharing
                        try? FileManager.default.removeItem(at: packageURL)
                        tempPackageURL = nil
                        showingShareSheet = false
                    }
                }
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK", role: .cancel) { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
        }
    }

    func deleteItem() {
        viewModel.delete(recording: recording)
        self.presentationMode.wrappedValue.dismiss()
    }

    func shareItem() {
        isCreatingPackage = true

        Task {
            do {
                let packageURL = try await ShareUtility.createShareableArchive(for: recording)
                await MainActor.run {
                    tempPackageURL = packageURL
                    isCreatingPackage = false
                    showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isCreatingPackage = false
                    shareError = error.localizedDescription
                }
            }
        }
    }
}

/// Step through a recording frame by frame: the camera image and, when recorded, its LiDAR depth.
struct FrameViewer: View {
    let summary: RecordingSummary
    @StateObject private var loader: FrameLoader
    @State private var index: Double = 0

    init(directory: URL, summary: RecordingSummary) {
        self.summary = summary
        _loader = StateObject(wrappedValue: FrameLoader(directory: directory, summary: summary))
    }

    var body: some View {
        let count = summary.frameTimes.count
        VStack(spacing: 10) {
            frame(loader.rgb, aspect: summary.aspect)
            if summary.depthFrames > 0 {
                // 256x192 in 4:3 formats, 256x144 in 4K (16:9): use the map's own shape.
                frame(loader.depth, aspect: loader.depth.map { Double($0.size.width / $0.size.height) } ?? summary.aspect)
                Text(loader.depthText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                legend
            }
            if count > 1 {
                Slider(value: $index, in: 0...Double(count - 1), step: 1)
                    .padding(.horizontal)
            }
            Text(count > 0
                 ? String(format: "Frame %d of %d · %.2f s", Int(index) + 1, count, summary.frameTimes[Int(index)] - summary.frameTimes[0])
                 : "No frames")
                .font(.caption)
                .monospacedDigit()
        }
        .task(id: Int(index)) {
            await loader.load(Int(index))
        }
    }

    private func frame(_ image: UIImage?, aspect: Double) -> some View {
        ZStack {
            Color.black
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .padding(.horizontal)
    }

    private var legend: some View {
        HStack(spacing: 6) {
            Text("near").font(.caption2)
            LinearGradient(colors: (0...4).map { i -> Color in
                let c = DepthColorizer.color(Float(i) / 4)
                return Color(red: Double(c.0), green: Double(c.1), blue: Double(c.2))
            }, startPoint: .leading, endPoint: .trailing)
                .frame(height: 8)
                .cornerRadius(4)
            Text("5 m+").font(.caption2)
        }
        .padding(.horizontal, 40)
    }
}

final class FrameLoader: ObservableObject {
    @Published var rgb: UIImage?
    @Published var depth: UIImage?
    @Published var depthText = ""
    private let directory: URL
    private let summary: RecordingSummary
    private let generator: AVAssetImageGenerator

    init(directory: URL, summary: RecordingSummary) {
        self.directory = directory
        self.summary = summary
        generator = AVAssetImageGenerator(asset: AVURLAsset(url: directory.appendingPathComponent("rgb.mp4")))
        generator.requestedTimeToleranceBefore = .zero // the exact frame, so it lines up with its depth map
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 1280, height: 1280)
    }

    @MainActor
    func load(_ index: Int) async {
        guard index < summary.frameTimes.count else { return }
        // RoadCapture stamps video frames with their capture time, so frame i plays at t_i - t_0.
        let time = CMTime(seconds: summary.frameTimes[index] - summary.frameTimes[0], preferredTimescale: 600)
        if let result = try? await generator.image(at: time), !Task.isCancelled {
            rgb = UIImage(cgImage: result.image)
        }
        guard summary.depthFrames > 0 else { return }
        let url = directory.appendingPathComponent("depth").appendingPathComponent(String(format: "%06d.png", index))
        let rendered = await Task.detached { DepthColorizer.render(url) }.value
        if Task.isCancelled { return }
        depth = rendered.image.map { UIImage(cgImage: $0) }
        depthText = rendered.text
    }
}

struct RecordingFacts: View {
    let summary: RecordingSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(summary.facts, id: \.0) { label, value in
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    Text(value)
                    Spacer()
                }
                .font(.callout)
            }
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// BEGIN RecordingSummary (Foundation only, so the Mac check can run this exact code)
/// What a recording folder holds, read from capture_info.json and the CSVs.
struct RecordingSummary {
    var width = 0
    var height = 0
    var cameraFps = 0
    var captureMode = ""
    var deviceModel = ""
    var iosVersion = ""
    var frameTimes: [Double] = []      // odometry.csv timestamps, in video order
    var pathLength = 0.0               // metres along ARKit's trajectory
    var trackingNormal: Double?        // share of frames with normal tracking (frames.csv)
    var gpsFixes = 0
    var depthFrames = 0

    var duration: Double { (frameTimes.last ?? 0) - (frameTimes.first ?? 0) }
    var aspect: Double { width > 0 && height > 0 ? Double(width) / Double(height) : 4.0 / 3.0 }

    var facts: [(String, String)] {
        var f: [(String, String)] = []
        if width > 0 {
            f.append(("Format", "\(width)×\(height) at \(cameraFps) fps" + (captureMode.isEmpty ? "" : " (\(captureMode))")))
        }
        f.append(("Length", String(format: "%.1f s · %d frames", duration, frameTimes.count)))
        f.append(("ARKit path", String(format: "%.1f m", pathLength)))
        if let t = trackingNormal {
            f.append(("Tracking", String(format: "normal on %.0f%% of frames", t * 100)))
        }
        f.append(("LiDAR depth", depthFrames > 0 ? "\(depthFrames) frames" : "off"))
        f.append(("GPS", "\(gpsFixes) fixes"))
        if !deviceModel.isEmpty {
            f.append(("Phone", "\(deviceModel) · iOS \(iosVersion)"))
        }
        return f
    }

    static func load(from directory: URL) -> RecordingSummary {
        var s = RecordingSummary()
        if let info = captureInfo(directory) {
            s.width = info["width"] as? Int ?? 0
            s.height = info["height"] as? Int ?? 0
            s.cameraFps = info["camera_fps"] as? Int ?? 0
            s.captureMode = info["capture_mode"] as? String ?? ""
            s.deviceModel = info["device_model"] as? String ?? ""
            s.iosVersion = info["ios_version"] as? String ?? ""
        }
        var last: (Double, Double, Double)?
        for row in rows(directory.appendingPathComponent("odometry.csv")) {
            guard let t = Double(row["timestamp"] ?? ""), let x = Double(row["x"] ?? ""),
                  let y = Double(row["y"] ?? ""), let z = Double(row["z"] ?? "") else { continue }
            s.frameTimes.append(t)
            if let p = last {
                s.pathLength += ((x - p.0) * (x - p.0) + (y - p.1) * (y - p.1) + (z - p.2) * (z - p.2)).squareRoot()
            }
            last = (x, y, z)
        }
        let frames = rows(directory.appendingPathComponent("frames.csv"))
        if !frames.isEmpty {
            s.trackingNormal = Double(frames.filter { $0["tracking_state"] == "normal" }.count) / Double(frames.count)
            s.depthFrames = frames.filter { $0["has_depth"] == "1" }.count
        } else {
            // Plain Stray Scanner recordings have no frames.csv: count the depth files instead.
            let depthDir = directory.appendingPathComponent("depth").path
            s.depthFrames = ((try? FileManager.default.contentsOfDirectory(atPath: depthDir)) ?? []).filter { $0.hasSuffix(".png") }.count
        }
        s.gpsFixes = rows(directory.appendingPathComponent("gps.csv")).count
        return s
    }

    /// "5s · 4K30 · LiDAR" for the recordings list; reads only capture_info.json.
    static func rowDetails(directory: URL, duration: Double) -> String {
        var parts = [String(format: "%ds", Int(duration.rounded()))]
        if let info = captureInfo(directory) {
            if let mode = info["capture_mode"] as? String { parts.append(mode) }
            if info["depth_enabled"] as? Bool == true { parts.append("LiDAR") }
        }
        return parts.joined(separator: " · ")
    }

    static func captureInfo(_ directory: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("capture_info.json")) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Rows of a ", "-separated CSV whose first line is the header.
    static func rows(_ url: URL) -> [[String: String]] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }
        let header = lines.removeFirst().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.map { line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            var row: [String: String] = [:]
            for (i, key) in header.enumerated() where i < fields.count {
                row[key] = fields[i]
            }
            return row
        }
    }
}
// END RecordingSummary

// BEGIN DepthColorizer (CoreGraphics + ImageIO only, so the Mac check can run this exact code)
/// Reads the 16-bit millimetre depth PNGs and colours them near (red) to far (blue).
enum DepthColorizer {
    static func render(_ url: URL, maxMetres: Float = 5) -> (image: CGImage?, text: String) {
        guard let depth = loadDepth(url) else { return (nil, "No depth for this frame") }
        let image = colorize(depth.metres, width: depth.width, height: depth.height, maxMetres: maxMetres)
        let valid = depth.metres.filter { $0 > 0 }.sorted()
        guard !valid.isEmpty else { return (image, "No valid depth in this frame") }
        let centre = depth.metres[(depth.height / 2) * depth.width + depth.width / 2]
        return (image, String(format: "Centre %.2f m · median %.2f m · nearest %.2f m", centre, valid[valid.count / 2], valid[0]))
    }

    /// Depth in metres, row by row, from a 16-bit greyscale PNG in millimetres.
    static func loadDepth(_ url: URL) -> (width: Int, height: Int, metres: [Float])? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.bitsPerComponent == 16, image.bitsPerPixel == 16,
              let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let width = image.width, height = image.height, stride = image.bytesPerRow
        let little = image.bitmapInfo.contains(.byteOrder16Little) // PNG itself is big-endian
        var metres = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * stride + x * 2
                let raw = little ? UInt16(bytes[i]) | UInt16(bytes[i + 1]) << 8
                                 : UInt16(bytes[i]) << 8 | UInt16(bytes[i + 1])
                metres[y * width + x] = Float(raw) / 1000
            }
        }
        return (width, height, metres)
    }

    /// 0 means "no reading" and stays black; everything past maxMetres is the far colour.
    static func colorize(_ metres: [Float], width: Int, height: Int, maxMetres: Float = 5) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for (i, d) in metres.enumerated() {
            let c = d > 0 ? color(min(d / maxMetres, 1)) : (0, 0, 0)
            rgba[i * 4] = UInt8(c.0 * 255)
            rgba[i * 4 + 1] = UInt8(c.1 * 255)
            rgba[i * 4 + 2] = UInt8(c.2 * 255)
            rgba[i * 4 + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// Red (near) → yellow → green → cyan → blue (far), for t in 0...1.
    static func color(_ t: Float) -> (Float, Float, Float) {
        let stops: [(Float, Float, Float)] = [(0.85, 0.10, 0.10), (0.95, 0.80, 0.10), (0.20, 0.80, 0.30),
                                              (0.10, 0.70, 0.90), (0.15, 0.20, 0.75)]
        let x = max(0, min(1, t)) * Float(stops.count - 1)
        let i = min(Int(x), stops.count - 2)
        let f = x - Float(i)
        let a = stops[i], b = stops[i + 1]
        return (a.0 + (b.0 - a.0) * f, a.1 + (b.1 - a.1) * f, a.2 + (b.2 - a.2) * f)
    }
}
// END DepthColorizer

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let completionWithItemsHandler: UIActivityViewController.CompletionWithItemsHandler?

    init(activityItems: [Any], completionHandler: UIActivityViewController.CompletionWithItemsHandler? = nil) {
        self.activityItems = activityItems
        self.completionWithItemsHandler = completionHandler
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = completionWithItemsHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {
    }
}

struct SessionDetailView_Previews: PreviewProvider {
    static var recording: Recording = { () -> Recording in
        let rec = Recording()
        rec.id = UUID()
        rec.name = "Placeholder name"
        rec.createdAt = Date()
        rec.duration = 30.0
        return rec
    }()

    static var previews: some View {
        SessionDetailView(recording: recording)
    }
}
