# 快速入門指南

## 🚀 5分鐘快速開始

### 步驟1: 準備測試文件

你已經有了示例SRT字幕文件，現在需要添加音頻文件。

#### 選項A: 使用現有音頻

從storytelling_cli目錄複製一個音頻文件：

```bash
# 在終端執行
cd /Users/chenliangyu/Desktop/podcast
cp storytelling_cli/test_multi_speaker_pro.wav audio-earning/audio-earning/Resources/sample_audio.wav
```

#### 選項B: 生成帶字幕的音頻

使用WhisperX生成精確對齊的字幕：

```bash
cd /Users/chenliangyu/Desktop/podcast/storytelling_cli/whisperx_alignment_test
python scripts/align_audio.py
# 生成的文件在 output/ 目錄
```

### 步驟2: 將文件添加到Xcode項目

1. 打開Xcode項目 `audio-earning.xcodeproj`
2. 右鍵點擊 `audio-earning` 文件夾
3. 選擇 "Add Files to audio-earning..."
4. 選擇音頻文件和SRT文件
5. **重要**: 確保勾選以下選項：
   - ✅ "Copy items if needed"
   - ✅ "Create groups"
   - ✅ 在 "Add to targets" 中勾選 "audio-earning"

### 步驟3: 運行項目

1. 選擇模擬器：iPhone 15 Pro 或更新版本
2. 點擊 Run 按鈕（或按 ⌘+R）
3. 等待編譯完成

如果遇到文件未找到的提示，說明文件名不匹配，請檢查：
- 音頻文件名是否爲 `sample_audio.wav`
- 字幕文件名是否爲 `sample_subtitle.srt`

## 📝 使用自己的音頻和字幕

### 創建音頻文件

你的音頻可以來自：
1. storytelling_cli（單人講故事）
2. podcast_cli（雙人對話）
3. 任何其他音頻源

### 生成SRT字幕

#### 方法1: 使用WhisperX自動生成

```bash
# 1. 準備音頻文件
cd /Users/chenliangyu/Desktop/podcast/storytelling_cli/whisperx_alignment_test

# 2. 將音頻複製到test_data目錄
cp your_audio.wav test_data/

# 3. 運行對齊腳本
python scripts/align_audio.py

# 4. 查看生成的SRT文件
cat output/subtitles.srt
```

#### 方法2: 手動創建SRT文件

使用文本編輯器創建，格式如下：

```srt
1
00:00:00,000 --> 00:00:02,500
第一句字幕

2
00:00:02,500 --> 00:00:05,000
第二句字幕
```

**時間格式說明**：
- 格式：`HH:MM:SS,mmm` (時:分:秒,毫秒)
- 例如：`00:01:23,456` = 1分23秒456毫秒
- 分隔符：`-->` (兩邊要有空格)

### 在代碼中使用自定義文件

編輯 `ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        if let audioURL = Bundle.main.url(forResource: "my_audio", withExtension: "wav"),
           let subtitleURL = Bundle.main.url(forResource: "my_subtitle", withExtension: "srt") {
            AudioPlayerView(audioURL: audioURL, subtitleURL: subtitleURL)
        } else {
            Text("文件未找到")
        }
    }
}
```

## 🎯 常見場景

### 場景1: 英語學習播客

1. 使用podcast_cli生成雙人對話音頻
2. 使用WhisperX生成逐字稿
3. 導入到app中，跟隨字幕學習發音

### 場景2: 有聲書學習

1. 使用storytelling_cli生成故事音頻
2. 生成分段字幕
3. 通過波形圖快速定位感興趣的部分

### 場景3: 自定義學習材料

1. 準備任何英語音頻（TED演講、新聞等）
2. 使用語音識別生成字幕
3. 在app中播放和學習

## 🔧 調試技巧

### 檢查文件是否正確添加

在 `AudioPlayerView.swift` 的 `onAppear` 中添加調試信息：

```swift
.onAppear {
    print("Audio URL: \(audioURL)")
    print("Subtitle URL: \(String(describing: subtitleURL))")
    viewModel.loadAudio(audioURL: audioURL, subtitleURL: subtitleURL)
}
```

### 查看字幕解析結果

在 `AudioPlayerViewModel.swift` 的 `loadAudio` 方法中查看打印：

```swift
✅ 已加載 13 條字幕  // 成功
❌ 字幕加載失敗: ... // 失敗
```

### 常見錯誤排查

#### 錯誤: "文件未找到"
- 解決：檢查文件是否添加到Xcode項目
- 確認文件名和擴展名是否正確

#### 錯誤: "Invalid SRT format"
- 解決：檢查SRT文件格式
- 確保時間碼格式正確
- 確保使用UTF-8編碼

#### 錯誤: "Invalid audio format"
- 解決：使用支持的音頻格式（WAV、MP3、M4A）
- 檢查音頻文件是否損壞

## 🎨 自定義外觀

### 修改字幕樣式

編輯 `SubtitleView.swift`:

```swift
Text(text.isEmpty ? "—" : text)
    .font(.system(size: 24, weight: .bold))  // 改變字體大小和粗細
    .foregroundColor(.blue)                   // 改變顏色
```

### 修改波形圖顏色

編輯 `WaveformView.swift`:

```swift
let color = isPlayed ? Color.green : Color.gray.opacity(0.3)  // 改變顏色
```

### 修改快進/快退時長

編輯 `PlayerControlsView.swift`:

```swift
viewModel.skip(seconds: -30)  // 快退30秒
viewModel.skip(seconds: 30)   // 快進30秒
```

## 📱 下一步

完成基礎功能後，可以考慮添加：

1. **多文件支持**: 添加文件列表，支持切換不同音頻
2. **書籤功能**: 保存學習進度
3. **單詞高亮**: 點擊字幕中的單詞查看釋義
4. **播放速度**: 添加0.5x、1x、1.5x、2x播放速度選項
5. **循環播放**: 重複播放選定片段
6. **導出筆記**: 將學習內容導出爲文本

## 💡 提示

- 使用耳機獲得最佳音質
- 在真機上測試以獲得最佳性能
- 定期保存Xcode項目
- 使用git管理代碼版本

## 🆘 獲取幫助

如果遇到問題：
1. 查看 README.md 中的故障排除部分
2. 檢查Xcode控制檯的錯誤信息
3. 確認所有文件都正確添加到項目

---

祝學習愉快！🎉
