//
//  ChapterListViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

@MainActor
final class ChapterListViewModel: ObservableObject {
    let book: Book

    @Published var chapters: [ChapterSummaryModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isOffline = false

    private let service: APIService
    private var hasLoaded = false

    init(book: Book, service: APIService = .shared) {
        self.book = book
        self.service = service
    }

    func loadChapters(force: Bool = false) {
        guard !hasLoaded || force else { return }
        hasLoaded = true

        Task { [weak self] in
            await self?.fetchChapters()
        }
    }

    private func fetchChapters() async {
        isLoading = true
        errorMessage = nil
        isOffline = false

        // 如果有本地快取，先展示
        if let cached = await ChapterListCacheStore.shared.list(for: book.id) {
            chapters = cached.chapters.map { summary in
                ChapterSummaryModel(
                    id: summary.id,
                    title: summary.title,
                    chapterNumber: summary.chapterNumber,
                    audioAvailable: summary.audioAvailable,
                    subtitlesAvailable: summary.subtitlesAvailable
                )
            }
        }

        do {
            let responses = try await service.fetchChapters(bookID: book.id)
            chapters = responses.map {
                ChapterSummaryModel(
                    id: $0.id,
                    title: $0.title,
                    chapterNumber: $0.chapterNumber,
                    audioAvailable: $0.audioAvailable,
                    subtitlesAvailable: $0.subtitlesAvailable
                )
            }

            let cachedChapters = responses.map { response in
                CachedChapterSummary(
                    id: response.id,
                    title: response.title,
                    chapterNumber: response.chapterNumber,
                    audioAvailable: response.audioAvailable,
                    subtitlesAvailable: response.subtitlesAvailable
                )
            }
            await ChapterListCacheStore.shared.save(bookID: book.id, chapters: cachedChapters)
        } catch {
            if chapters.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                isOffline = true
            }
        }

        isLoading = false
    }
}
