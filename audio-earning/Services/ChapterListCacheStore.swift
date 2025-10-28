//
//  ChapterListCacheStore.swift
//  audio-earning
//
//  Created by Claude on 2025/10/28.
//

import Foundation

struct CachedChapterSummary: Codable, Equatable {
    let id: String
    let title: String
    let chapterNumber: Int?
    let audioAvailable: Bool
    let subtitlesAvailable: Bool
}

struct CachedChapterList: Codable, Equatable {
    let bookID: String
    let chapters: [CachedChapterSummary]
    let cachedAt: Date

    var isEmpty: Bool { chapters.isEmpty }
}

actor ChapterListCacheStore {
    static let shared = ChapterListCacheStore()

    private let fileManager: FileManager
    private let storeURL: URL
    private var cache: [String: CachedChapterList] = [:]

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = supportDir.appendingPathComponent("chapter-cache", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        self.storeURL = folder.appendingPathComponent("chapter-list.json")
        loadFromDisk()
    }

    func save(bookID: String, chapters: [CachedChapterSummary]) {
        let list = CachedChapterList(bookID: bookID, chapters: chapters, cachedAt: Date())
        cache[bookID] = list
        persist()
    }

    func list(for bookID: String) -> CachedChapterList? {
        cache[bookID]
    }

    func clear(bookID: String) {
        cache.removeValue(forKey: bookID)
        persist()
    }

    func clearAll() {
        cache.removeAll()
        persist()
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode([String: CachedChapterList].self, from: data)
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
#if DEBUG
            print("⚠️ 無法儲存章節列表快取：\(error.localizedDescription)")
#endif
        }
    }
}
