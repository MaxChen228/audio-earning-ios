//
//  PlayerControlsView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// 播放控制視圖
struct PlayerControlsView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 進度條
            ProgressSlider(
                currentTime: viewModel.currentTime,
                totalDuration: viewModel.totalDuration,
                onSeek: { time in
                    viewModel.seek(to: time)
                }
            )
            .padding(.horizontal)

            // 控制按鈕
            HStack(spacing: 30) {
                // 快退15秒
                Button(action: {
                    viewModel.skip(seconds: -15)
                }) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }

                // 播放/暫停
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                }

                // 快進15秒
                Button(action: {
                    viewModel.skip(seconds: 15)
                }) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var isPlaying: Bool {
        viewModel.playerState == .playing
    }
}

/// 進度條滑塊
struct ProgressSlider: View {
    let currentTime: TimeInterval
    let totalDuration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var tempValue: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景軌道
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                    .cornerRadius(2)

                // 已播放進度
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: progressWidth(in: geometry.size.width), height: 4)
                    .cornerRadius(2)

                // 拖動手柄
                Circle()
                    .fill(Color.blue)
                    .frame(width: 16, height: 16)
                    .offset(x: progressWidth(in: geometry.size.width) - 8)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                isDragging = true
                                let x = max(0, min(gesture.location.x, geometry.size.width))
                                tempValue = Double(x / geometry.size.width) * totalDuration
                            }
                            .onEnded { _ in
                                isDragging = false
                                onSeek(tempValue)
                            }
                    )
            }
        }
        .frame(height: 20)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let progress = isDragging ? tempValue : currentTime
        guard totalDuration > 0 else { return 0 }
        return CGFloat(progress / totalDuration) * totalWidth
    }
}

#Preview {
    VStack {
        // 創建一個測試用的ViewModel
        let viewModel = AudioPlayerViewModel()
        PlayerControlsView(viewModel: viewModel)
            .padding()
    }
}
