//
//  BookModels.swift
//  audio-earning
//
//  Created by Codex on 2025/10/27.
//

import Foundation

/// 書籍資料模型（供 SwiftUI 使用）
struct Book: Identifiable, Hashable {
    let id: String
    let title: String
}

/// 章節摘要資料模型
struct ChapterSummaryModel: Identifiable, Hashable {
    let id: String
    let title: String
    let chapterNumber: Int?
    let audioAvailable: Bool
    let subtitlesAvailable: Bool
}

/// 章節播放資訊模型
struct ChapterPlaybackModel: Identifiable, Hashable {
    let id: String
    let title: String
    let chapterNumber: Int?
    let audioURL: URL?
    let subtitlesURL: URL?
}
