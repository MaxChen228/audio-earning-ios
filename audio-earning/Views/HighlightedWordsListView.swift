//
//  HighlightedWordsListView.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import SwiftUI

/// 已標記單字列表視圖
struct HighlightedWordsListView: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.highlightedWordsSorted.isEmpty {
                    Label("目前尚未標記任何單字", systemImage: "bookmark")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.highlightedWordsSorted, id: \.self) { word in
                        HStack {
                            Text(word.capitalized)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeHighlight(word)
                            } label: {
                                Text("取消標記")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("已標記單字")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("關閉") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.highlightedWordsSorted.isEmpty {
                        Button("清除全部", role: .destructive) {
                            viewModel.clearAllHighlightedWords()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HighlightedWordsListView(viewModel: AudioPlayerViewModel())
}
