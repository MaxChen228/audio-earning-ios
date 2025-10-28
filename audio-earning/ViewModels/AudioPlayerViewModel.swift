//
//  AudioPlayerViewModel.swift
//  audio-earning
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import AVFoundation
import Combine

/// 音頻播放器ViewModel - 使用MVVM架構
/// 使用 AVAudioEngine 進行播放和實時音頻分析
class AudioPlayerViewModel: NSObject, ObservableObject {

    // MARK: - Published Properties (驅動UI更新)

    @Published var playerState: AudioPlayerState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var currentSubtitle: SubtitleItem?
    @Published var currentSubtitleText: String = ""
    @Published var progress: Double = 0 // 0.0 ~ 1.0
    @Published private(set) var displayedSubtitles: [SubtitleItem] = []

    // 🆕 已標記單字集合（儲存正規化後的單字）
    @Published private(set) var highlightedWords: Set<String> = [] {
        didSet {
            saveHighlightedWords()
        }
    }

    // 🆕 字幕顯示模式
    @Published var displayMode: SubtitleDisplayMode = .wordLevel

    // MARK: - Private Properties

    private var audioEngine: AudioEngineManager!
    private var playbackTimer: Timer?
    private let timerInterval: TimeInterval = 1.0 / 30.0
    private let highlightedWordsStorageKey = "audioEarning.highlightedWords"

    // 🆕 雙字幕數據源
    private var wordLevelSubtitles: [SubtitleItem] = []     // 原始逐字字幕
    private var sentenceLevelSubtitles: [SubtitleItem] = [] // 預處理的句子字幕
    private var subtitles: [SubtitleItem] = []              // 當前使用的字幕

    private var currentSubtitleIndex: Int = 0 // 優化字幕查找性能

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioSession()
        setupAudioEngine()
        loadHighlightedWords()
    }

    deinit {
        stopPlaybackTimer()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("❌ 音頻會話設置失敗: \(error.localizedDescription)")
        }
    }

    private func setupAudioEngine() {
        audioEngine = AudioEngineManager()
    }

    // MARK: - Public Methods

    /// 加載音頻和字幕
    /// - Parameters:
    ///   - audioURL: 音頻文件URL
    ///   - subtitleURL: SRT字幕文件URL（可選）
    func loadAudio(audioURL: URL, subtitleURL: URL? = nil, subtitleContent: String? = nil) {
        playerState = .loading
        stopPlaybackTimer()

        do {
            // 加載音頻
            try audioEngine.loadAudio(url: audioURL) { [weak self] in
                self?.handlePlaybackFinished()
            }

            // 獲取時長
            totalDuration = audioEngine.duration

            currentTime = 0
            progress = 0
            currentSubtitleIndex = 0
            clearCurrentSubtitle()
            displayedSubtitles = []

            // 🆕 加載字幕並預處理
            loadSubtitlesIfNeeded(url: subtitleURL, content: subtitleContent)

            playerState = .ready
        } catch {
            playerState = .error(error.localizedDescription)
            print("❌ 音頻加載失敗: \(error.localizedDescription)")
        }
    }

    /// 檢查單字是否已被標記
    func isWordHighlighted(_ word: String) -> Bool {
        let normalized = normalizeWord(word)
        guard !normalized.isEmpty else { return false }
        return highlightedWords.contains(normalized)
    }

    /// 標記指定單字
    func highlightWord(_ word: String) {
        let normalized = normalizeWord(word)
        guard !normalized.isEmpty else { return }
        highlightedWords.insert(normalized)
    }

    /// 取消標記指定單字
    func removeHighlight(_ word: String) {
        let normalized = normalizeWord(word)
        guard !normalized.isEmpty else { return }
        highlightedWords.remove(normalized)
    }

    /// 清除所有標記單字
    func clearAllHighlightedWords() {
        highlightedWords.removeAll()
    }

    /// 依字母排序後的標記清單（供UI顯示）
    var highlightedWordsSorted: [String] {
        highlightedWords.sorted()
    }

    /// 已標記單字數量
    var highlightedWordsCount: Int {
        highlightedWords.count
    }

    /// 播放
    func play() {
        let needsRestart = playerState == .finished || currentTime >= totalDuration - 0.001

        if needsRestart {
            currentSubtitleIndex = 0
            clearCurrentSubtitle()
            currentTime = 0
            progress = 0
            audioEngine.seek(to: 0, shouldResume: true)
        } else {
            audioEngine.play()
        }

        playerState = .playing
        refreshCurrentTime(fallback: needsRestart ? 0 : nil)
        startPlaybackTimer()
        updateProgress()
        updateSubtitle(for: currentTime)
    }

    /// 暫停
    func pause() {
        refreshCurrentTime()
        audioEngine.pause()
        playerState = .paused
        stopPlaybackTimer()
        updateProgress()
        updateSubtitle(for: currentTime)
    }

    private func loadSubtitlesIfNeeded(url: URL?, content: String?) {
        do {
            let rawSubtitles: [SubtitleItem]

            if let content = content {
                rawSubtitles = try SRTParser.parse(content: content)
            } else if let url = url {
                rawSubtitles = try SRTParser.parse(url: url)
            } else {
                wordLevelSubtitles = []
                sentenceLevelSubtitles = []
                subtitles = []
                return
            }

            #if DEBUG
            print("✅ 已載入 \(rawSubtitles.count) 條字幕")
            #endif

            wordLevelSubtitles = rawSubtitles
            sentenceLevelSubtitles = mergeSentences(from: rawSubtitles, anticipation: 0.3)
            updateSubtitleDataSource()
        } catch {
            #if DEBUG
            print("❌ 字幕載入失敗: \(error.localizedDescription)")
            #endif
            wordLevelSubtitles = []
            sentenceLevelSubtitles = []
            subtitles = []
            displayedSubtitles = []
        }
    }

    /// 切換播放/暫停
    func togglePlayPause() {
        switch playerState {
        case .playing:
            pause()
        case .finished:
            currentSubtitleIndex = 0
            play()
        default:
            play()
        }
    }

    /// 跳轉到指定時間
    /// - Parameter time: 目標時間（秒）
    func seek(to time: TimeInterval, autoResume: Bool = true) {
        let clampedTime = max(0, min(totalDuration, time))
        let shouldResume = autoResume && (playerState == .playing || audioEngine.isPlaying)

        audioEngine.seek(to: clampedTime, shouldResume: shouldResume)

        refreshCurrentTime(fallback: clampedTime)
        updateProgress()
        updateSubtitle(for: currentTime)

        if shouldResume {
            playerState = .playing
            startPlaybackTimer()
        } else {
            playerState = .paused
            stopPlaybackTimer()
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshCurrentTime()
            self.updateProgress()
            self.updateSubtitle(for: self.currentTime)
        }
    }

    /// 快進/快退
    /// - Parameter seconds: 秒數（正數快進，負數快退）
    func skip(seconds: Double) {
        let newTime = max(0, min(totalDuration, currentTime + seconds))
        seek(to: newTime)
    }

    /// 切換字幕顯示模式
    /// - Parameter mode: 新的顯示模式
    func setDisplayMode(_ mode: SubtitleDisplayMode) {
        displayMode = mode

        // 🆕 切換字幕數據源
        updateSubtitleDataSource()

        // 重置索引並更新字幕
        currentSubtitleIndex = 0
        updateSubtitle(for: currentTime)
    }

    /// 🆕 根據當前模式更新字幕數據源
    private func updateSubtitleDataSource() {
        switch displayMode {
        case .wordLevel:
            subtitles = wordLevelSubtitles
            print("🔄 切換到逐字模式：\(subtitles.count) 個詞")
        case .sentenceLevel:
            subtitles = sentenceLevelSubtitles
            print("🔄 切換到逐句模式：\(subtitles.count) 個句子")
        }

        displayedSubtitles = subtitles
    }

    // MARK: - Playback Timer

    private func startPlaybackTimer() {
        stopPlaybackTimer()
        let timer = Timer(timeInterval: timerInterval, repeats: true) { [weak self] _ in
            self?.updatePlaybackState()
        }
        playbackTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlaybackState() {
        refreshCurrentTime(allowIncrement: true)
        updateProgress()
        updateSubtitle(for: currentTime)
    }

    private func refreshCurrentTime(fallback: TimeInterval? = nil, allowIncrement: Bool = false) {
        if let engineTime = audioEngine.getCurrentTime() {
            currentTime = min(max(engineTime, 0), totalDuration)
        } else if let fallback = fallback {
            currentTime = min(max(fallback, 0), totalDuration)
        } else if allowIncrement && audioEngine.isPlaying {
            currentTime = min(currentTime + timerInterval, totalDuration)
        }
    }

    private func updateProgress() {
        if totalDuration > 0 {
            progress = currentTime / totalDuration
        }
    }

    // MARK: - Subtitle Management

    /// 更新當前字幕（高效查找算法）
    /// - Parameter time: 當前播放時間
    private func updateSubtitle(for time: TimeInterval) {
        guard !subtitles.isEmpty else {
            clearCurrentSubtitle()
            return
        }

        guard let index = subtitleIndex(for: time) else {
            currentSubtitleIndex = 0
            clearCurrentSubtitle()
            return
        }

        currentSubtitleIndex = index
        updateCurrentSubtitle(subtitles[index])
    }

    /// 更新當前字幕
    private func updateCurrentSubtitle(_ subtitle: SubtitleItem) {
        if currentSubtitle?.id != subtitle.id {
            currentSubtitle = subtitle
            // 🆕 直接顯示字幕文本（已經預處理好了）
            currentSubtitleText = subtitle.text
        }
    }

    /// 清空當前字幕（現在不再使用，保留以防需要）
    private func clearCurrentSubtitle() {
        currentSubtitle = nil
        currentSubtitleText = ""
    }

    /// 使用者主動操作（拖曳、點擊）時暫停播放，等待手動恢復
    func pauseForUserInteraction() {
        if playerState == .playing {
            pause()
        }
    }

    private func subtitleIndex(for time: TimeInterval) -> Int? {
        var low = 0
        var high = subtitles.count - 1
        var candidate: Int?

        while low <= high {
            let mid = (low + high) / 2
            let subtitle = subtitles[mid]

            if subtitle.contains(time: time) {
                return mid
            }

            if time < subtitle.startTime {
                high = mid - 1
            } else {
                candidate = mid
                low = mid + 1
            }
        }

        return candidate
    }

    // MARK: - Sentence Processing (預處理)

    /// 🆕 將 word-level 字幕預處理成 sentence-level
    /// - Parameters:
    ///   - wordSubtitles: 原始逐字字幕
    ///   - anticipation: 提前顯示時間（秒）
    /// - Returns: 句子級別字幕陣列
    private func mergeSentences(
        from wordSubtitles: [SubtitleItem],
        anticipation: TimeInterval = 0.3
    ) -> [SubtitleItem] {
        guard !wordSubtitles.isEmpty else { return [] }

        var sentences: [SubtitleItem] = []
        var currentWords: [SubtitleItem] = []
        var sentenceID = 1

        for subtitle in wordSubtitles {
            currentWords.append(subtitle)

            let trimmedText = subtitle.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let lastCharacter = trimmedText.last
            let shouldEndSentence = lastCharacter.map { ".?!".contains($0) } ?? false

            if shouldEndSentence {
                let sentenceText = currentWords.map { $0.text }.joined(separator: " ")
                let sentenceStart = max(0, currentWords.first!.startTime - anticipation)
                let sentenceEnd = currentWords.last!.endTime

                let sentence = SubtitleItem(
                    id: sentenceID,
                    startTime: sentenceStart,
                    endTime: sentenceEnd,
                    text: sentenceText
                )

                sentences.append(sentence)
                sentenceID += 1
                currentWords.removeAll()
            }
        }

        if !currentWords.isEmpty {
            let sentenceText = currentWords.map { $0.text }.joined(separator: " ")
            let sentenceStart = max(0, currentWords.first!.startTime - anticipation)
            let sentenceEnd = currentWords.last!.endTime

            let sentence = SubtitleItem(
                id: sentenceID,
                startTime: sentenceStart,
                endTime: sentenceEnd,
                text: sentenceText
            )

            sentences.append(sentence)
        }

        print("✅ 句子預處理完成：\(wordSubtitles.count) 個詞 → \(sentences.count) 個句子")
        return sentences
    }

    // MARK: - Playback Completion

    private func handlePlaybackFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.stopPlaybackTimer()
            self.refreshCurrentTime(fallback: self.totalDuration)
            self.playerState = .finished
            self.updateProgress()
            self.updateSubtitle(for: self.currentTime)
        }
    }

    // MARK: - Highlight Persistence

    private func normalizeWord(_ word: String) -> String {
        let lowered = word.lowercased()
        let allowed = CharacterSet.alphanumerics
        let filteredScalars = lowered.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(filteredScalars))
    }

    private func loadHighlightedWords() {
        let stored = UserDefaults.standard.stringArray(forKey: highlightedWordsStorageKey) ?? []
        highlightedWords = Set(stored)
    }

    private func saveHighlightedWords() {
        UserDefaults.standard.set(Array(highlightedWords), forKey: highlightedWordsStorageKey)
    }
}
