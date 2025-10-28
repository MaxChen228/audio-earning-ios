//
//  ChapterPlayerView.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import SwiftUI

struct ChapterPlayerView: View {
    let book: Book
    let chapter: ChapterSummaryModel

    @StateObject private var viewModel: ChapterPlayerViewModel

    init(book: Book, chapter: ChapterSummaryModel) {
        self.book = book
        self.chapter = chapter
        _viewModel = StateObject(wrappedValue: ChapterPlayerViewModel(book: book, chapter: chapter))
    }

    var body: some View {
        content
            .navigationTitle(chapter.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                viewModel.loadIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text("取得章節內容中…")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .noAudio:
            VStack(spacing: 12) {
                Image(systemName: "waveform.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("尚未提供音訊")
                    .font(.headline)
                Text("這個章節尚未生成音檔，請稍後再試。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .error(let message):
            VStack(spacing: 12) {
                Image(systemName: "xmark.octagon")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("載入失敗")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Button("重新嘗試") {
                    viewModel.retry()
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

        case .ready(let localAudioURL, let subtitleContent):
            AudioPlayerView(
                audioURL: localAudioURL,
                subtitleContent: subtitleContent,
                chapterTitle: chapter.title
            )
        }
    }
}

#Preview {
    NavigationStack {
        ChapterPlayerView(
            book: Book(id: "demo", title: "Demo Book"),
            chapter: ChapterSummaryModel(id: "chapter0", title: "Warm up", chapterNumber: 1, audioAvailable: true, subtitlesAvailable: true)
        )
    }
}
