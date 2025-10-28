//
//  APIService.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

/// 後端 API 基本設定
struct APIConfiguration {
    static var shared = APIConfiguration()

    /// 本機模擬器使用 127.0.0.1，實體裝置改用區網 IP
    var baseURL: URL = {
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000")!
        #else
        // 實體裝置連線使用 Mac 的區網 IP
        return URL(string: "http://192.168.1.113:8000")!
        #endif
    }()
}

/// 後端書籍資料模型
struct BookResponse: Decodable, Identifiable {
    let id: String
    let title: String
}

/// 後端章節摘要資料模型
struct ChapterResponse: Decodable, Identifiable {
    let id: String
    let title: String
    let chapterNumber: Int?
    let audioAvailable: Bool
    let subtitlesAvailable: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case chapterNumber = "chapter_number"
        case audioAvailable = "audio_available"
        case subtitlesAvailable = "subtitles_available"
    }
}

/// 章節播放詳細資料
struct ChapterPlaybackResponse: Decodable {
    let id: String
    let title: String
    let chapterNumber: Int?
    let audioURL: URL?
    let subtitlesURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case chapterNumber = "chapter_number"
        case audioURL = "audio_url"
        case subtitlesURL = "subtitles_url"
    }
}

enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無效的 URL"
        case .invalidResponse:
            return "伺服器回應格式不正確"
        case .httpError(let code):
            return "伺服器回傳錯誤狀態碼：\(code)"
        case .decodingFailed:
            return "解析伺服器資料失敗"
        case .fileWriteFailed:
            return "檔案寫入失敗"
        }
    }
}

struct SubtitleDownload: Equatable {
    let content: String
    let fileURL: URL
}

/// 與 FastAPI 後端互動的服務
final class APIService {
    static let shared = APIService()

    private let session: URLSession
    private let fileManager: FileManager
    private let cacheDirectory: URL

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
        self.cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent("audio-cache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public APIs

    func fetchBooks() async throws -> [BookResponse] {
        let url = APIConfiguration.shared.baseURL.appendingPathComponent("books")
        return try await request(url)
    }

    func fetchChapters(bookID: String) async throws -> [ChapterResponse] {
        let url = APIConfiguration.shared.baseURL
            .appendingPathComponent("books")
            .appendingPathComponent(bookID)
            .appendingPathComponent("chapters")
        return try await request(url)
    }

    func fetchChapterDetail(bookID: String, chapterID: String) async throws -> ChapterPlaybackResponse {
        let url = APIConfiguration.shared.baseURL
            .appendingPathComponent("books")
            .appendingPathComponent(bookID)
            .appendingPathComponent("chapters")
            .appendingPathComponent(chapterID)
        return try await request(url)
    }

    /// 下載音檔並回傳本機暫存位置
    func downloadAudio(from url: URL) async throws -> URL {
        let destination = cachedFileURL(for: url)
        let metaURL = etagFileURL(for: url)
        let remoteETag = try await fetchETag(for: url)
        let hasLocalFile = fileManager.fileExists(atPath: destination.path)

        if let remoteETag,
           hasLocalFile,
           let storedETag = try? String(contentsOf: metaURL).trimmingCharacters(in: .whitespacesAndNewlines),
           storedETag == remoteETag {
            #if DEBUG
            print("🔁 使用快取音檔：\(url.lastPathComponent)")
            #endif
            return destination
        }

        if remoteETag == nil, hasLocalFile {
            #if DEBUG
            print("🔁 使用本地音檔（伺服器無提供 ETag）：\(url.lastPathComponent)")
            #endif
            return destination
        }

        #if DEBUG
        print("⬇️ 重新下載音檔：\(url.lastPathComponent)")
        #endif

        let (tempURL, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIServiceError.invalidResponse
        }

        do {
            if hasLocalFile {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)

            if let etag = remoteETag ?? http.value(forHTTPHeaderField: "ETag") {
                try etag.write(to: metaURL, atomically: true, encoding: .utf8)
            } else {
                try? fileManager.removeItem(at: metaURL)
            }

            return destination
        } catch {
            throw APIServiceError.fileWriteFailed
        }
    }

    /// 下載 SRT 字幕（回傳內容與本地檔案位置）
    func downloadSubtitles(from url: URL) async throws -> SubtitleDownload {
        let destination = cachedTextURL(for: url)
        let metaURL = destination.appendingPathExtension("etag")
        let remoteETag = try await fetchETag(for: url)
        let hasCachedSubtitle = fileManager.fileExists(atPath: destination.path)

        if let remoteETag,
           hasCachedSubtitle,
           let storedETag = try? String(contentsOf: metaURL).trimmingCharacters(in: .whitespacesAndNewlines),
           storedETag == remoteETag,
           let cached = try? String(contentsOf: destination, encoding: .utf8) {
            #if DEBUG
            print("🔁 使用快取字幕：\(url.lastPathComponent)")
            #endif
            return SubtitleDownload(content: cached, fileURL: destination)
        }

        if remoteETag == nil,
           hasCachedSubtitle,
           let cached = try? String(contentsOf: destination, encoding: .utf8) {
            #if DEBUG
            print("🔁 使用本地字幕（伺服器無提供 ETag）：\(url.lastPathComponent)")
            #endif
            return SubtitleDownload(content: cached, fileURL: destination)
        }

        #if DEBUG
        print("⬇️ 重新下載字幕：\(url.lastPathComponent)")
        #endif

        var request = URLRequest(url: url)
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIServiceError.invalidResponse
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw APIServiceError.decodingFailed
        }

        do {
            try content.write(to: destination, atomically: true, encoding: .utf8)
            if let etag = remoteETag ?? http.value(forHTTPHeaderField: "ETag") {
                try etag.write(to: metaURL, atomically: true, encoding: .utf8)
            } else {
                try? fileManager.removeItem(at: metaURL)
            }
        } catch {
            throw APIServiceError.fileWriteFailed
        }

        return SubtitleDownload(content: content, fileURL: destination)
    }

    // MARK: - Private helpers

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            throw APIServiceError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIServiceError.decodingFailed
        }
    }

    private func cachedFileURL(for remoteURL: URL) -> URL {
        let forbiddenCharacters: CharacterSet = {
            var set = CharacterSet.alphanumerics.inverted
            set.remove(charactersIn: "._-")
            return set
        }()

        let sanitized = remoteURL.absoluteString
            .components(separatedBy: forbiddenCharacters)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        return cacheDirectory.appendingPathComponent(sanitized)
    }

    private func cachedTextURL(for remoteURL: URL) -> URL {
        cachedFileURL(for: remoteURL).appendingPathExtension("srt")
    }

    private func etagFileURL(for remoteURL: URL) -> URL {
        cachedFileURL(for: remoteURL).appendingPathExtension("etag")
    }

    private func fetchETag(for url: URL) async throws -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return nil
            }
            guard 200..<300 ~= http.statusCode else {
                return nil
            }
            return http.value(forHTTPHeaderField: "ETag")
        } catch {
            return nil
        }
    }
}
