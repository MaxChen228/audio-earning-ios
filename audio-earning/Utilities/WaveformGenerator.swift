//
//  WaveformGenerator.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import AVFoundation
import Accelerate

/// 波形圖生成器
/// 使用預處理方式提取音頻振幅數據，生成可視化波形
class WaveformGenerator {

    /// 波形數據結構
    struct WaveformData {
        let samples: [Float]  // 歸一化的振幅值 (0.0 ~ 1.0)
        let duration: TimeInterval
    }

    /// 生成波形數據
    /// - Parameters:
    ///   - audioURL: 音頻文件URL
    ///   - targetSampleCount: 目標採樣點數量（通常爲屏幕寬度的像素數）
    /// - Returns: 波形數據
    static func generateWaveform(from audioURL: URL, targetSampleCount: Int = 500) async throws -> WaveformData {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let waveformData = try processAudioFile(url: audioURL, targetSampleCount: targetSampleCount)
                    continuation.resume(returning: waveformData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 處理音頻文件（核心算法）
    private static func processAudioFile(url: URL, targetSampleCount: Int) throws -> WaveformData {
        // 1. 打開音頻文件
        let audioFile = try AVAudioFile(forReading: url)

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: audioFile.processingFormat.sampleRate,
            channels: 1,  // 轉換爲單聲道
            interleaved: false
        ) else {
            throw WaveformError.invalidFormat
        }

        // 2. 獲取音頻基本信息
        let totalFrames = Int(audioFile.length)
        let duration = Double(totalFrames) / audioFile.processingFormat.sampleRate

        guard totalFrames > 0 else {
            throw WaveformError.emptyFile
        }

        // 3. 創建音頻緩衝區
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalFrames)
        ) else {
            throw WaveformError.bufferCreationFailed
        }

        // 4. 讀取整個音頻文件到緩衝區
        try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(totalFrames))

        // 5. 提取音頻採樣數據
        guard let channelData = buffer.floatChannelData?[0] else {
            throw WaveformError.noChannelData
        }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: totalFrames))

        // 6. 降採樣 (Downsample) - 關鍵優化
        let downsampledSamples = downsample(samples: samples, targetCount: targetSampleCount)

        // 7. 歸一化到 0.0 ~ 1.0 範圍
        let normalizedSamples = normalize(samples: downsampledSamples)

        return WaveformData(samples: normalizedSamples, duration: duration)
    }

    /// 降採樣算法
    /// 將大量採樣點壓縮爲目標數量，保留最大振幅
    private static func downsample(samples: [Float], targetCount: Int) -> [Float] {
        guard samples.count > targetCount else {
            return samples
        }

        var result: [Float] = []
        let bucketSize = samples.count / targetCount

        for i in 0..<targetCount {
            let startIndex = i * bucketSize
            let endIndex = min(startIndex + bucketSize, samples.count)

            // 在每個bucket中找到最大振幅（取絕對值）
            var maxAmplitude: Float = 0
            for j in startIndex..<endIndex {
                let absValue = abs(samples[j])
                if absValue > maxAmplitude {
                    maxAmplitude = absValue
                }
            }

            result.append(maxAmplitude)
        }

        return result
    }

    /// 歸一化振幅值到 0.0 ~ 1.0 範圍
    private static func normalize(samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }

        // 找到最大振幅
        var maxAmplitude: Float = 0
        for sample in samples {
            if sample > maxAmplitude {
                maxAmplitude = sample
            }
        }

        guard maxAmplitude > 0 else {
            return samples.map { _ in 0.0 }
        }

        // 歸一化
        return samples.map { $0 / maxAmplitude }
    }

    /// 使用vDSP加速的降採樣（可選優化版本）
    private static func downsampleAccelerated(samples: [Float], targetCount: Int) -> [Float] {
        guard samples.count > targetCount else {
            return samples
        }

        var result = [Float](repeating: 0, count: targetCount)
        let bucketSize = samples.count / targetCount

        for i in 0..<targetCount {
            let startIndex = i * bucketSize
            let endIndex = min(startIndex + bucketSize, samples.count)
            let bucketSamples = Array(samples[startIndex..<endIndex])

            // 使用vDSP計算RMS（均方根）
            var rms: Float = 0
            vDSP_rmsqv(bucketSamples, 1, &rms, vDSP_Length(bucketSamples.count))
            result[i] = rms
        }

        return result
    }
}

/// 波形生成錯誤
enum WaveformError: LocalizedError {
    case invalidFormat
    case emptyFile
    case bufferCreationFailed
    case noChannelData

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid audio format"
        case .emptyFile:
            return "Audio file is empty"
        case .bufferCreationFailed:
            return "Failed to create audio buffer"
        case .noChannelData:
            return "No audio channel data available"
        }
    }
}
