//
//  ChapterPlayerViewModel.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

@MainActor
final class ChapterPlayerViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case ready(localAudioURL: URL, subtitleContent: String?)
        case noAudio
        case error(String)
    }

    @Published private(set) var state: State = .idle

    let book: Book
    let chapter: ChapterSummaryModel

    private let service: APIService
    private var hasLoaded = false

    init(book: Book, chapter: ChapterSummaryModel, service: APIService = .shared) {
        self.book = book
        self.chapter = chapter
        self.service = service
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        state = .loading

        Task { [weak self] in
            await self?.loadChapter()
        }
    }

    func retry() {
        hasLoaded = false
        loadIfNeeded()
    }

    private func loadChapter() async {
        do {
            let detail = try await service.fetchChapterDetail(bookID: book.id, chapterID: chapter.id)

            guard let audioURL = detail.audioURL else {
                state = .noAudio
                await ChapterCacheStore.shared.removeChapter(bookID: book.id, chapterID: chapter.id)
                return
            }

            let localAudio = try await service.downloadAudio(from: audioURL)

            var subtitlesContent: String?
            var subtitleFilePath: String?
            if let subtitleURL = detail.subtitlesURL {
                if let payload = try? await service.downloadSubtitles(from: subtitleURL) {
                    subtitlesContent = payload.content
                    subtitleFilePath = payload.fileURL.path
                }
            }

            state = .ready(localAudioURL: localAudio, subtitleContent: subtitlesContent)

            let cachedChapter = CachedChapter(
                bookID: book.id,
                chapterID: chapter.id,
                chapterTitle: detail.title,
                chapterNumber: detail.chapterNumber,
                audioURLString: audioURL.absoluteString,
                subtitlesURLString: detail.subtitlesURL?.absoluteString,
                localAudioPath: localAudio.path,
                localSubtitlePath: subtitleFilePath,
                subtitleContent: subtitlesContent,
                cachedAt: Date()
            )
            await ChapterCacheStore.shared.saveChapter(cachedChapter)
        } catch {
            if let cached = await ChapterCacheStore.shared.cachedChapter(bookID: book.id, chapterID: chapter.id),
               FileManager.default.fileExists(atPath: cached.localAudioPath) {
                let audioURL = cached.localAudioURL
                var subtitleContent = cached.subtitleContent

                if let subtitlePath = cached.localSubtitlePath,
                   FileManager.default.fileExists(atPath: subtitlePath),
                   let cachedText = try? String(contentsOf: URL(fileURLWithPath: subtitlePath), encoding: .utf8) {
                    subtitleContent = cachedText
                }

                state = .ready(localAudioURL: audioURL, subtitleContent: subtitleContent)
                return
            }

            state = .error(error.localizedDescription)
        }
    }
}
