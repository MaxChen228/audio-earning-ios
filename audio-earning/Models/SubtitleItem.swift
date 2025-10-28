//
//  SubtitleItem.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation

/// 字幕項數據結構
struct SubtitleItem: Identifiable, Equatable {
    let id: Int
    let startTime: TimeInterval  // 開始時間（秒）
    let endTime: TimeInterval    // 結束時間（秒）
    let text: String             // 字幕文本

    /// 檢查給定時間是否在此字幕的時間範圍內
    func contains(time: TimeInterval) -> Bool {
        return time >= startTime && time <= endTime
    }

    /// 計算字幕持續時間
    var duration: TimeInterval {
        return endTime - startTime
    }
}

/// 音頻播放器狀態
enum AudioPlayerState: Equatable {
    case idle        // 空閒
    case loading     // 加載中
    case ready       // 準備就緒
    case playing     // 播放中
    case paused      // 暫停
    case finished    // 播放完成
    case error(String) // 錯誤狀態

    // 實現 Equatable，讓狀態可以比較
    static func == (lhs: AudioPlayerState, rhs: AudioPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.ready, .ready),
             (.playing, .playing),
             (.paused, .paused),
             (.finished, .finished):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// 字幕顯示模式
enum SubtitleDisplayMode: String, CaseIterable {
    case wordLevel = "逐字"      // 一次顯示一個詞（word-level）
    case sentenceLevel = "逐句"  // 合併顯示多個連續詞（sentence-level）

    var description: String {
        return self.rawValue
    }
}
