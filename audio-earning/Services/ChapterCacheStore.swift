//
//  ChapterCacheStore.swift
//  audio-earning
//
//  Created by Claude on 2025/10/28.
//

import Foundation

struct CachedChapter: Codable, Equatable {
    let bookID: String
    let chapterID: String
    let chapterTitle: String
    let chapterNumber: Int?
    let audioURLString: String
    let subtitlesURLString: String?
    let localAudioPath: String
    let localSubtitlePath: String?
    let subtitleContent: String?
    let cachedAt: Date

    var localAudioURL: URL {
        URL(fileURLWithPath: localAudioPath)
    }

    var remoteAudioURL: URL? {
        URL(string: audioURLString)
    }

    var remoteSubtitleURL: URL? {
        guard let subtitlesURLString else { return nil }
        return URL(string: subtitlesURLString)
    }
}

actor ChapterCacheStore {
    static let shared = ChapterCacheStore()

    private var cache: [String: CachedChapter] = [:]
    private let storeURL: URL
    private let fileManager: FileManager

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = supportDir.appendingPathComponent("chapter-cache", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        self.storeURL = folder.appendingPathComponent("chapters.json")
        loadFromDisk()
    }

    private func cacheKey(bookID: String, chapterID: String) -> String {
        "\(bookID)#\(chapterID)"
    }

    func cachedChapter(bookID: String, chapterID: String) -> CachedChapter? {
        cache[cacheKey(bookID: bookID, chapterID: chapterID)]
    }

    func saveChapter(_ chapter: CachedChapter) {
        cache[cacheKey(bookID: chapter.bookID, chapterID: chapter.chapterID)] = chapter
        persist()
    }

    func removeChapter(bookID: String, chapterID: String) {
        cache.removeValue(forKey: cacheKey(bookID: bookID, chapterID: chapterID))
        persist()
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode([String: CachedChapter].self, from: data)
            cache = decoded
        } catch {
            cache = [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Ignore persisting errors in release; cache will repopulate next time.
#if DEBUG
            print("⚠️ 無法儲存章節快取：\(error.localizedDescription)")
#endif
        }
    }
}
