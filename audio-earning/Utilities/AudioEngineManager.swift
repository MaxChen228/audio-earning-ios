//
//  AudioEngineManager.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import AVFoundation

/// 音頻引擎管理器
/// 使用 AVAudioEngine 播放音頻
class AudioEngineManager {

    // MARK: - Properties

    private var audioEngine: AVAudioEngine!
    private var audioPlayerNode: AVAudioPlayerNode!
    private var audioFile: AVAudioFile?

    private var currentSegmentStartTime: TimeInterval = 0
    private var playbackCompletionHandler: (() -> Void)?
    private var ignoreNextCompletion = false

    // 🆕 頻譜分析回調
    var onFrequencyUpdate: (([Float]) -> Void)?

    // MARK: - Initialization

    init() {
        setupAudioEngine()
    }

    deinit {
        audioEngine?.stop()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioEngine.attach(audioPlayerNode)
    }

    // MARK: - Load Audio

    func loadAudio(url: URL, onComplete: (() -> Void)? = nil) throws {
        #if DEBUG
        print("🎵 開始加載音頻: \(url.lastPathComponent)")
        #endif

        // 0. 先停止現有的引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        ignoreNextCompletion = true
        audioPlayerNode.stop()

        // 1. 讀取音頻文件
        audioFile = try AVAudioFile(forReading: url)

        guard let audioFile = audioFile else {
            throw AudioEngineError.invalidFile
        }

        let format = audioFile.processingFormat
        #if DEBUG
        print("✅ 音頻格式: \(format.sampleRate)Hz, \(format.channelCount)聲道")
        #endif

        // 2. 重新連接節點（先斷開再連接）
        audioEngine.disconnectNodeOutput(audioPlayerNode)
        audioEngine.connect(
            audioPlayerNode,
            to: audioEngine.mainMixerNode,
            format: format
        )

        // 3. 啟動引擎
        try audioEngine.start()

        // 4. 排程整個音頻文件
        playbackCompletionHandler = onComplete
        currentSegmentStartTime = 0
        scheduleFile()
        ignoreNextCompletion = false

        #if DEBUG
        print("✅ 音頻引擎已啟動，總時長: \(duration)秒")
        #endif
    }

    private func scheduleFile() {
        guard let audioFile = audioFile else { return }

        audioPlayerNode.scheduleFile(
            audioFile,
            at: nil,
            completionHandler: { [weak self] in
                self?.handleNodeCompletion()
            }
        )
    }

    // MARK: - Playback Control

    func play() {
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        audioPlayerNode.play()
    }

    func pause() {
        audioPlayerNode.pause()
    }

    func stop() {
        audioPlayerNode.stop()
        audioEngine.stop()
    }

    var isPlaying: Bool {
        return audioPlayerNode.isPlaying
    }

    // MARK: - Seek

    func seek(to time: TimeInterval, shouldResume: Bool) {
        guard let audioFile = audioFile else { return }

        let sampleRate = audioFile.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let frameCount = audioFile.length - startFrame

        guard startFrame >= 0, frameCount > 0 else { return }

        // 停止當前播放
        ignoreNextCompletion = true
        audioPlayerNode.stop()

        // 重新排程從指定位置開始
        audioPlayerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(frameCount),
            at: nil,
            completionHandler: { [weak self] in
                self?.handleNodeCompletion()
            }
        )

        currentSegmentStartTime = time

        if shouldResume {
            play()
        }

        ignoreNextCompletion = false
    }

    // MARK: - Properties

    var duration: TimeInterval {
        guard let audioFile = audioFile else { return 0 }
        let sampleRate = audioFile.processingFormat.sampleRate
        return Double(audioFile.length) / sampleRate
    }

    /// 獲取當前播放時間
    /// 注意：AVAudioPlayerNode 沒有直接的 currentTime 屬性
    /// 需要通過其他方式追蹤（在 ViewModel 中使用 Timer）
    func getCurrentTime() -> TimeInterval? {
        guard let nodeTime = audioPlayerNode.lastRenderTime,
              let playerTime = audioPlayerNode.playerTime(forNodeTime: nodeTime) else {
            return nil
        }

        let sampleRate = audioFile?.processingFormat.sampleRate ?? 44100
        let elapsed = Double(playerTime.sampleTime) / sampleRate
        return currentSegmentStartTime + elapsed
    }

    // MARK: - Completion Handling

    private func handleNodeCompletion() {
        if ignoreNextCompletion {
            ignoreNextCompletion = false
            return
        }

        playbackCompletionHandler?()
    }

}

/// 音頻引擎錯誤
enum AudioEngineError: LocalizedError {
    case invalidFile
    case engineNotStarted

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid audio file"
        case .engineNotStarted:
            return "Audio engine not started"
        }
    }
}
