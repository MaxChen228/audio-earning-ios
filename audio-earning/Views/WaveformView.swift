//
//  WaveformView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// 波形圖視圖
/// 使用Canvas繪製音頻波形，並顯示播放進度
struct WaveformView: View {
    let samples: [Float]       // 振幅數據 (0.0 ~ 1.0)
    let progress: Double       // 播放進度 (0.0 ~ 1.0)
    let height: CGFloat        // 視圖高度

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let width = size.width
                let barWidth: CGFloat = max(1.0, width / CGFloat(samples.count))
                let spacing: CGFloat = 0.5

                // 繪製波形
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * barWidth
                    let barHeight = CGFloat(sample) * height * 0.8  // 最大高度爲80%

                    // 計算矩形
                    let rect = CGRect(
                        x: x,
                        y: (height - barHeight) / 2,
                        width: barWidth - spacing,
                        height: barHeight
                    )

                    // 判斷是否在已播放區域
                    let isPlayed = CGFloat(index) / CGFloat(samples.count) < progress

                    // 設置顏色
                    let color = isPlayed ? Color.blue : Color.gray.opacity(0.3)
                    context.fill(Path(rect), with: .color(color))
                }

                // 繪製播放進度指示線
                let progressX = width * progress
                let progressLine = Path { path in
                    path.move(to: CGPoint(x: progressX, y: 0))
                    path.addLine(to: CGPoint(x: progressX, y: height))
                }
                context.stroke(progressLine, with: .color(.blue), lineWidth: 2)
            }
        }
        .frame(height: height)
    }
}

/// 波形圖容器（帶加載狀態）
struct WaveformContainerView: View {
    let audioURL: URL?
    let progress: Double

    @State private var waveformData: WaveformGenerator.WaveformData?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("生成波形圖...")
                    .frame(height: 80)
            } else if let waveformData = waveformData {
                WaveformView(
                    samples: waveformData.samples,
                    progress: progress,
                    height: 80
                )
            } else if let error = errorMessage {
                Text("波形加載失敗: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .frame(height: 80)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 80)
                    .overlay(
                        Text("無波形數據")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onChange(of: audioURL) { _, newURL in
            if let url = newURL {
                loadWaveform(from: url)
            }
        }
        .onAppear {
            if let url = audioURL {
                loadWaveform(from: url)
            }
        }
    }

    private func loadWaveform(from url: URL) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await WaveformGenerator.generateWaveform(from: url, targetSampleCount: 500)
                await MainActor.run {
                    self.waveformData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        // 示例1: 靜態波形
        WaveformView(
            samples: (0..<100).map { _ in Float.random(in: 0...1) },
            progress: 0.3,
            height: 80
        )
        .padding()

        // 示例2: 不同進度
        WaveformView(
            samples: (0..<100).map { _ in Float.random(in: 0...1) },
            progress: 0.7,
            height: 80
        )
        .padding()
    }
}
