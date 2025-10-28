# 技術架構文檔

## 📐 架構概覽

本項目採用現代iOS開發最佳實踐，使用**SwiftUI + AVFoundation + MVVM**架構。

```
┌─────────────────────────────────────────────────────┐
│                   SwiftUI Views                     │
│  (AudioPlayerView, WaveformView, SubtitleView)     │
└─────────────────┬───────────────────────────────────┘
                  │ @ObservedObject
                  │ @Published
┌─────────────────▼───────────────────────────────────┐
│             AudioPlayerViewModel                    │
│  - 持有 AVPlayer                                     │
│  - 管理播放狀態                                      │
│  - 字幕同步邏輯                                      │
└─────────────────┬───────────────────────────────────┘
                  │ 使用
┌─────────────────▼───────────────────────────────────┐
│              AVFoundation                           │
│  - AVPlayer (音頻播放)                              │
│  - AVAudioFile (波形數據提取)                        │
│  - addPeriodicTimeObserver (時間同步)               │
└─────────────────────────────────────────────────────┘
```

## 🏛️ MVVM模式詳解

### Model層

#### SubtitleItem.swift
```swift
struct SubtitleItem: Identifiable, Equatable {
    let id: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}
```

**設計要點**：
- `Identifiable`: 支持SwiftUI ForEach
- `Equatable`: 支持狀態比較
- `TimeInterval`: 使用秒爲單位，便於計算

#### AudioPlayerState
```swift
enum AudioPlayerState {
    case idle, loading, ready, playing, paused, finished
    case error(String)
}
```

**設計要點**：
- 清晰的狀態機設計
- 關聯值承載錯誤信息

### ViewModel層

#### AudioPlayerViewModel.swift

**核心職責**：
1. 音頻播放控制
2. 字幕同步
3. 狀態管理
4. UI驅動

**關鍵實現**：

```swift
class AudioPlayerViewModel: ObservableObject {
    // MARK: - Published Properties (驅動UI)
    @Published var playerState: AudioPlayerState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var currentSubtitleText: String = ""
    @Published var progress: Double = 0

    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var subtitles: [SubtitleItem] = []
    private var currentSubtitleIndex: Int = 0  // 性能優化關鍵
}
```

**爲什麼這樣設計**：
- `@Published`: 自動觸發UI更新
- `private player`: 封裝AVPlayer，外部只能通過方法操作
- `currentSubtitleIndex`: 避免每次都從頭查找字幕

### View層

#### 組件化設計

```
AudioPlayerView (主視圖)
├── WaveformContainerView (波形圖容器)
│   └── WaveformView (波形圖繪製)
├── SubtitleContainerView (字幕容器)
│   └── SubtitleView (字幕顯示)
└── PlayerControlsView (播放控制)
    └── ProgressSlider (進度條)
```

**每個組件職責單一**：
- `AudioPlayerView`: 整合所有組件
- `WaveformView`: 只負責繪製
- `SubtitleView`: 只負責顯示
- `PlayerControlsView`: 只負責交互

## 🎵 音頻播放核心

### AVPlayer選擇原因

**爲什麼不用AVAudioPlayer**：
- ❌ AVAudioPlayer: 簡單播放，但時間同步不夠精確
- ✅ AVPlayer: 支持精確的時間觀察，適合字幕同步

### 時間觀察器實現

```swift
private func addPeriodicTimeObserver() {
    let interval = CMTime(seconds: 0.1, preferredTimescale: 600)

    timeObserver = player.addPeriodicTimeObserver(
        forInterval: interval,
        queue: .main
    ) { [weak self] time in
        // 每0.1秒回調一次
        let currentSeconds = CMTimeGetSeconds(time)
        self?.updateSubtitle(for: currentSeconds)
    }
}
```

**關鍵參數**：
- `interval: 0.1秒`: 平衡性能和精度
- `preferredTimescale: 600`: CMTime精度
- `queue: .main`: 在主線程更新UI
- `[weak self]`: 避免循環引用

### 爲什麼是0.1秒？

| 間隔時間 | 優點 | 缺點 |
|---------|------|------|
| 0.05秒 | 更流暢 | CPU佔用高 |
| 0.1秒 ✅ | 平衡最佳 | - |
| 0.2秒 | CPU佔用低 | 字幕可能跳躍 |

## 📝 字幕同步算法

### 高效查找策略

**問題**：有100條字幕，如何快速找到當前時間對應的字幕？

**❌ 錯誤做法**：每次都遍歷所有字幕
```swift
// 時間複雜度: O(n)，每0.1秒執行一次，浪費性能
for subtitle in subtitles {
    if subtitle.contains(time: currentTime) {
        // 找到了
    }
}
```

**✅ 優化做法**：記住當前索引
```swift
// 時間複雜度: O(1) 或 O(k)，k通常很小
if currentSubtitleIndex < subtitles.count,
   subtitles[currentSubtitleIndex].contains(time: time) {
    return  // 當前字幕仍然有效，O(1)
}

// 只在需要時向前或向後查找，O(k)
// k = 需要跳過的字幕數量，通常爲1-2
```

### 查找邏輯流程圖

```
當前時間 → 檢查currentSubtitleIndex是否有效
              │
              ├─ 是 → 直接使用 (O(1))
              │
              └─ 否 → 判斷播放方向
                      │
                      ├─ 向前 → 從index+1開始查找
                      │
                      └─ 向後 → 從index-1開始查找
```

### 二分查找優化（可選）

對於字幕數量非常多的場景（>1000條），可以使用二分查找：

```swift
private func binarySearchSubtitle(time: TimeInterval) -> SubtitleItem? {
    var left = 0
    var right = subtitles.count - 1

    while left <= right {
        let mid = (left + right) / 2
        let subtitle = subtitles[mid]

        if subtitle.contains(time: time) {
            return subtitle
        } else if time < subtitle.startTime {
            right = mid - 1
        } else {
            left = mid + 1
        }
    }

    return nil
}
```

**複雜度對比**：
- 順序查找: O(n)
- 索引優化: O(1) ~ O(k)
- 二分查找: O(log n)

## 📊 波形圖生成

### 爲什麼預處理？

**❌ 實時處理方案**：
```swift
// 使用AVAudioEngine實時分析
// 問題：
// 1. CPU佔用高（持續處理）
// 2. 適合錄音，不適合播放
// 3. 需要配置複雜的音頻鏈路
```

**✅ 預處理方案**：
```swift
// 一次性讀取和處理
// 優點：
// 1. 只在加載時處理一次
// 2. 結果可以緩存
// 3. 代碼簡單清晰
```

### 處理流程

```
音頻文件 (幾百萬採樣點)
    ↓
讀取到AVAudioPCMBuffer
    ↓
提取Float數組 (原始採樣)
    ↓
降採樣 (Downsample)
    ↓
500個代表性採樣點
    ↓
歸一化到0.0~1.0
    ↓
用於SwiftUI繪製
```

### 降採樣算法

```swift
func downsample(samples: [Float], targetCount: Int) -> [Float] {
    let bucketSize = samples.count / targetCount

    var result: [Float] = []
    for i in 0..<targetCount {
        let start = i * bucketSize
        let end = start + bucketSize

        // 在每個bucket中找最大振幅
        let maxAmplitude = samples[start..<end].max() ?? 0
        result.append(maxAmplitude)
    }

    return result
}
```

**爲什麼取最大值**：
- 保留波形的"峯值"特徵
- 視覺效果更明顯
- 符合音頻可視化習慣

**其他可選方案**：
- RMS (均方根): 更平滑，但峯值不明顯
- 平均值: 太平滑，失去波形特徵

### 歸一化原因

```swift
// 原始振幅: [-1.0, 1.0]
// 問題：負值無法直接用於高度計算

// 歸一化後: [0.0, 1.0]
// 優點：
// 1. 可以直接作爲高度百分比
// 2. 便於縮放到任意高度
// 3. 便於比較不同音頻
```

## 🎨 UI繪製技術

### SwiftUI Canvas

**爲什麼用Canvas而不是Shape**：

```swift
// ❌ 使用Shape會創建大量View
ForEach(samples.indices, id: \.self) { index in
    Rectangle()  // 500個View！性能差
}

// ✅ 使用Canvas只有一個View
Canvas { context, size in
    for sample in samples {
        context.fill(...)  // 純繪製，性能好
    }
}
```

### 繪製優化

```swift
Canvas { context, size in
    // 1. 計算一次，重複使用
    let barWidth = size.width / CGFloat(samples.count)

    // 2. 批量繪製，減少狀態切換
    for (index, sample) in samples.enumerated() {
        let isPlayed = index < progressIndex
        let color = isPlayed ? Color.blue : Color.gray

        // 3. 直接繪製，不創建中間對象
        context.fill(rect, with: .color(color))
    }
}
```

## 🔄 狀態管理

### @Published驅動UI

```
用戶點擊播放
    ↓
viewModel.play()
    ↓
player.play()
    ↓
timeObserver觸發
    ↓
currentTime = 1.23  // @Published
    ↓
SwiftUI自動重繪
    ↓
UI更新
```

### 單向數據流

```
UI (View)  →  Event  →  ViewModel  →  @Published  →  UI更新
    ↑                                                    │
    └────────────────────────────────────────────────────┘
```

**優點**：
- 數據流向清晰
- 易於調試
- 狀態可預測

## 🚀 性能優化

### 1. 字幕查找優化
- 使用索引記憶
- 避免重複查找
- 時間複雜度: O(1)

### 2. 波形圖優化
- 預處理，只生成一次
- 降採樣到合理數量
- 使用Canvas繪製

### 3. UI更新優化
- 使用@Published自動更新
- 避免不必要的重繪
- 合理的觀察器頻率

### 4. 內存管理
- 使用[weak self]避免循環引用
- 及時釋放observer
- 合理的緩存策略

## 🧪 可測試性

### ViewModel單元測試

```swift
func testSubtitleSync() {
    let viewModel = AudioPlayerViewModel()
    let testSubtitles = [
        SubtitleItem(id: 1, startTime: 0, endTime: 2, text: "Hello"),
        SubtitleItem(id: 2, startTime: 2, endTime: 4, text: "World")
    ]

    // 測試字幕切換
    XCTAssertEqual(viewModel.currentSubtitleText, "")
    viewModel.updateSubtitle(for: 1.0)
    XCTAssertEqual(viewModel.currentSubtitleText, "Hello")
}
```

## 📱 擴展性

### 添加新功能建議

1. **播放速度控制**：
   - 在ViewModel添加`playbackRate`屬性
   - 使用`player.rate = playbackRate`

2. **書籤功能**：
   - 添加`Bookmark`模型
   - 使用UserDefaults或CoreData持久化

3. **多文件支持**：
   - 創建`AudioLibrary`模型
   - 添加文件列表View

4. **離線緩存**：
   - 使用URLCache
   - 或實現自定義緩存策略

## 🎯 最佳實踐總結

1. **架構**: MVVM + SwiftUI
2. **音頻**: AVPlayer + TimeObserver
3. **字幕**: 索引優化查找
4. **波形**: 預處理 + Canvas
5. **狀態**: @Published驅動
6. **性能**: 合理優化，不過度優化
7. **代碼**: 職責單一，易於維護

## 📚 參考資料

- [AVFoundation Programming Guide](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/AVFoundationPG/)
- [SwiftUI Data Flow](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
- [Core Audio Overview](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/)
