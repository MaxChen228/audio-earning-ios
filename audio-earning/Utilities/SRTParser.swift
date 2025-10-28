//
//  SRTParser.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation

/// SRT字幕解析器
/// 支持標準SRT格式解析，將字幕轉換爲SubtitleItem數組
class SRTParser {

    /// 解析SRT文件
    /// - Parameter url: SRT文件URL
    /// - Returns: 字幕項數組
    static func parse(url: URL) throws -> [SubtitleItem] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parse(content: content)
    }

    /// 解析SRT內容
    /// - Parameter content: SRT文件內容字符串
    /// - Returns: 字幕項數組
    static func parse(content: String) throws -> [SubtitleItem] {
        var subtitles: [SubtitleItem] = []

        // 使用雙換行分割字幕塊
        let blocks = content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for block in blocks {
            // 分割每一行
            let lines = block.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard lines.count >= 3 else { continue }

            // 第1行：索引
            guard let id = Int(lines[0]) else { continue }

            // 第2行：時間戳 (格式: 00:00:00,000 --> 00:00:05,200)
            let timeRange = lines[1]
            guard let (startTime, endTime) = parseTimeRange(timeRange) else {
                continue
            }

            // 第3+行：字幕文本（可能多行）
            let text = lines[2...].joined(separator: "\n")

            let subtitle = SubtitleItem(
                id: id,
                startTime: startTime,
                endTime: endTime,
                text: text
            )

            subtitles.append(subtitle)
        }

        // 按開始時間排序
        return subtitles.sorted { $0.startTime < $1.startTime }
    }

    /// 解析時間範圍
    /// - Parameter timeRange: 時間範圍字符串 (例如: "00:00:00,000 --> 00:00:05,200")
    /// - Returns: (開始時間, 結束時間) 元組，單位爲秒
    private static func parseTimeRange(_ timeRange: String) -> (TimeInterval, TimeInterval)? {
        let components = timeRange.components(separatedBy: " --> ")
        guard components.count == 2 else { return nil }

        guard let startTime = parseTimestamp(components[0]),
              let endTime = parseTimestamp(components[1]) else {
            return nil
        }

        return (startTime, endTime)
    }

    /// 解析時間戳
    /// - Parameter timestamp: 時間戳字符串 (格式: "00:01:23,456")
    /// - Returns: 時間間隔（秒）
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        // 格式: HH:MM:SS,mmm
        let components = timestamp.components(separatedBy: CharacterSet(charactersIn: ":,"))
        guard components.count == 4 else { return nil }

        guard let hours = Double(components[0]),
              let minutes = Double(components[1]),
              let seconds = Double(components[2]),
              let milliseconds = Double(components[3]) else {
            return nil
        }

        // 轉換爲總秒數
        let totalSeconds = hours * 3600 + minutes * 60 + seconds + milliseconds / 1000.0
        return totalSeconds
    }
}

/// SRT解析錯誤
enum SRTParserError: LocalizedError {
    case invalidFormat
    case fileNotFound
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid SRT format"
        case .fileNotFound:
            return "SRT file not found"
        case .encodingError:
            return "Failed to decode SRT file"
        }
    }
}
