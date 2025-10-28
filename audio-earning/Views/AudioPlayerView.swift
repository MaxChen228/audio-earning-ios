//
//  AudioPlayerView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// 音頻播放器主視圖
/// 整合波形圖、字幕和播放控制
struct AudioPlayerView: View {
    @StateObject private var viewModel = AudioPlayerViewModel()
    @State private var isShowingHighlightedWords = false

    let audioURL: URL
    let subtitleContent: String?
    let chapterTitle: String

    var body: some View {
        VStack(spacing: 24) {
            // 標題
            Text(chapterTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)

            Spacer()

            // 🆕 字幕顯示模式切換
            SubtitleModeToggleStyled(viewModel: viewModel)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // 字幕顯示
            SubtitleContainerView(viewModel: viewModel)
            .frame(minHeight: 100)

            Button {
                isShowingHighlightedWords = true
            } label: {
                Label("已標記單字 (\(viewModel.highlightedWordsCount))", systemImage: "bookmark")
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(Color.blue.opacity(viewModel.highlightedWordsCount > 0 ? 0.15 : 0.08))
                    )
                    .foregroundColor(.blue)
            }
            .opacity(viewModel.highlightedWordsCount == 0 ? 0.6 : 1.0)

            Spacer()

            // 播放控制
            PlayerControlsView(viewModel: viewModel)
                .padding(.horizontal)

            // 狀態指示器
            stateIndicator
                .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.loadAudio(audioURL: audioURL, subtitleContent: subtitleContent)
        }
        .sheet(isPresented: $isShowingHighlightedWords) {
            HighlightedWordsListView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.playerState {
        case .loading:
            HStack {
                ProgressView()
                Text("加載中...")
                    .foregroundColor(.secondary)
            }
        case .error(let message):
            Text("錯誤: \(message)")
                .foregroundColor(.red)
                .font(.caption)
        default:
            EmptyView()
        }
    }
}

/// 演示視圖（用於預覽）
struct AudioPlayerDemoView: View {
    var body: some View {
        if let audioURL = Bundle.main.url(forResource: "sample_audio", withExtension: "wav"),
           let subtitleURL = Bundle.main.url(forResource: "sample_subtitle", withExtension: "srt") {
            let subtitleContent = try? String(contentsOf: subtitleURL, encoding: .utf8)
            AudioPlayerView(audioURL: audioURL, subtitleContent: subtitleContent, chapterTitle: "範例章節")
        } else {
            VStack {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                Text("未找到示例文件")
                    .font(.headline)
                    .padding()
                Text("請確認示例音頻與字幕已加入目標的 Copy Bundle Resources")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        }
    }
}

#Preview {
    AudioPlayerDemoView()
}
