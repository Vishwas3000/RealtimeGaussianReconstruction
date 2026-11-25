//
//  SessionRow.swift
//  Stray Scanner
//
//  Created by Kenneth Blomqvist on 11/15/20.
//  Copyright © 2020 Stray Robots. All rights reserved.
//
//  RoadCapture changes: a thumbnail of the first frame and "5s · 4K30 · LiDAR" details.
//

import SwiftUI
import AVFoundation

struct SessionRow: View {
    var session: Recording
    @State private var thumbnail: UIImage?
    @State private var details = ""

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Color.gray.opacity(0.25)
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 96, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionTitle())
                    .multilineTextAlignment(.leading)
                Text(details.isEmpty ? String(format: "%ds", Int(round(session.duration))) : details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
        }
        .task {
            guard thumbnail == nil, let directory = session.directoryPath() else { return }
            details = RecordingSummary.rowDetails(directory: directory, duration: session.duration)
            // rgb.mp4 for ARKit recordings, the wide lens for multi-lens ones.
            let video = session.absoluteRgbPath() ?? directory.appendingPathComponent("rgb.mp4")
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: video))
            generator.maximumSize = CGSize(width: 320, height: 320)
            if let result = try? await generator.image(at: .zero) {
                thumbnail = UIImage(cgImage: result.image)
            }
        }
    }

    private func sessionTitle() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short

        if let created = session.createdAt {
            return dateFormatter.string(from: created)
        } else {
            return "Session"
        }
    }
}
