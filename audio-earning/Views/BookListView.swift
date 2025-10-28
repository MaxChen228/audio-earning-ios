//
//  BookListView.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import SwiftUI

struct BookListView: View {
    @StateObject private var viewModel = BookListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.books.isEmpty {
                ProgressView("載入書籍中…")
                    .padding()
            } else if let message = viewModel.errorMessage, viewModel.books.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                    Text("載入失敗")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重新整理") {
                        viewModel.loadBooks(force: true)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List(viewModel.books) { book in
                    NavigationLink(destination: ChapterListView(book: book)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title.isEmpty ? book.id : book.title)
                                .font(.headline)
                            Text(book.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    viewModel.loadBooks(force: true)
                }
            }
        }
        .navigationTitle("選擇書籍")
        .task {
            viewModel.loadBooks()
        }
    }
}

#Preview {
    NavigationStack {
        BookListView()
    }
}
