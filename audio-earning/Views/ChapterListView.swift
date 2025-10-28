//
//  ChapterListView.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import SwiftUI

struct ChapterListView: View {
    let book: Book
    @StateObject private var viewModel: ChapterListViewModel

    init(book: Book) {
        self.book = book
        _viewModel = StateObject(wrappedValue: ChapterListViewModel(book: book))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.chapters.isEmpty {
                ProgressView("載入章節中…")
                    .padding()
            } else if let message = viewModel.errorMessage, viewModel.chapters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("無法取得章節")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重新整理") {
                        viewModel.loadChapters(force: true)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    if viewModel.isOffline {
                        HStack(spacing: 6) {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(.orange)
                            Text("目前離線，顯示上次的章節資料")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    List(viewModel.chapters) { chapter in
                        NavigationLink(
                            destination: ChapterPlayerView(book: book, chapter: chapter)
                        ) {
                            ChapterRow(chapter: chapter)
                        }
                        .disabled(!chapter.audioAvailable)
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        viewModel.loadChapters(force: true)
                    }
                }
            }
        }
        .navigationTitle(book.title.isEmpty ? book.id : book.title)
        .task {
            viewModel.loadChapters()
        }
    }
}

private struct ChapterRow: View {
    let chapter: ChapterSummaryModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline)
                HStack(spacing: 8) {
                    Label(chapter.audioAvailable ? "音訊" : "無音訊", systemImage: chapter.audioAvailable ? "waveform" : "nosign")
                        .font(.caption)
                        .foregroundColor(chapter.audioAvailable ? .blue : .secondary)
                    Label(chapter.subtitlesAvailable ? "字幕" : "無字幕", systemImage: chapter.subtitlesAvailable ? "captions.bubble" : "text.badge.xmark")
                        .font(.caption)
                        .foregroundColor(chapter.subtitlesAvailable ? .green : .secondary)
                }
            }
            Spacer()
            if !chapter.audioAvailable {
                Text("待生成")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
    }

    private var titleText: String {
        if let number = chapter.chapterNumber {
            return "第\(number)章 · \(chapter.title)"
        }
        return chapter.title
    }
}

#Preview {
    NavigationStack {
        ChapterListView(
            book: Book(id: "demo", title: "Demo Book")
        )
    }
}
