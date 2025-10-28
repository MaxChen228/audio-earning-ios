# Audio Earning iOS

iOS 音頻學習應用 - 沉浸式播客播放器

## 功能特點

- 📚 書籍和章節瀏覽
- 🎧 高質量音頻播放
- 📝 實時詞級字幕同步
- 🎯 字幕高亮顯示
- 💾 音頻和章節緩存
- 🌊 波形可視化（可選）
- 🔄 ETag 緩存驗證

## 技術架構

### 平台
- iOS 16.0+
- Xcode 15+
- Swift 5.9+
- SwiftUI

### 核心組件

#### Services
- **APIService**: 後端 API 通訊
  - 書籍列表獲取
  - 章節詳情和音頻下載
  - ETag 緩存驗證
- **ChapterCacheStore**: 章節數據持久化
- **ChapterListCacheStore**: 章節列表緩存

#### ViewModels
- **BookListViewModel**: 書籍列表管理
- **ChapterListViewModel**: 章節列表管理
- **ChapterPlayerViewModel**: 播放器狀態管理
- **AudioPlayerViewModel**: 音頻播放控制

#### Views
- **BookListView**: 書籍瀏覽界面
- **ChapterListView**: 章節選擇界面
- **ChapterPlayerView**: 播放器主界面
- **SubtitleView**: 字幕顯示組件
- **PlayerControlsView**: 播放控制按鈕

#### Utilities
- **AudioEngineManager**: AVAudioEngine 音頻管理
- **SRTParser**: SRT 字幕解析器
- **WaveformGenerator**: 波形數據生成

## 快速開始

### 1. 環境配置

```bash
# 克隆倉庫
git clone <your-repo-url>
cd audio-earning-ios

# 使用 Xcode 打開項目
open audio-earning.xcodeproj
```

### 2. 後端 API 配置

在 `Services/APIService.swift` 中配置後端 URL：

```swift
private let baseURL = "http://your-backend-domain:8000"
// 或本地開發: "http://localhost:8000"
```

### 3. 運行應用

1. 選擇目標設備或模擬器
2. 點擊 ▶️ 運行
3. 確保後端服務已啟動

## 架構說明

### MVVM 架構
```
View ↔ ViewModel ↔ Service/Model
```

- **View**: SwiftUI 視圖，純 UI 渲染
- **ViewModel**: 狀態管理和業務邏輯
- **Service**: API 通訊和數據持久化

### 數據流

```
用戶操作 → ViewModel → APIService → 後端 API
                ↓
            緩存檢查
                ↓
          UI 狀態更新 → View 重繪
```

### 字幕同步機制

1. **時間追踪**: `Timer.publish` 每 50ms 檢查播放位置
2. **字幕匹配**: 二分搜索當前時間對應的字幕行
3. **詞級高亮**: 匹配當前播放時間的單詞並高亮
4. **自動滾動**: 高亮字幕自動滾動到可視區域

## API 端點

### 書籍列表
```http
GET /api/books
Response: [Book]
```

### 章節列表
```http
GET /api/books/{book_id}/chapters
Response: [ChapterSummary]
```

### 章節詳情
```http
GET /api/books/{book_id}/chapters/{chapter_id}
Response: ChapterDetail
```

### 音頻下載
```http
GET /api/audio/{book_id}/{chapter_id}
Headers: If-None-Match: <etag>
Response: Audio file (200) or 304 Not Modified
```

## 開發指南

### 添加新功能

1. **Model 定義** (`Models/`)
   ```swift
   struct NewFeature: Codable {
       let id: String
       let name: String
   }
   ```

2. **API 服務** (`Services/APIService.swift`)
   ```swift
   func fetchNewFeature() async throws -> NewFeature {
       // API 調用邏輯
   }
   ```

3. **ViewModel** (`ViewModels/`)
   ```swift
   @MainActor
   class NewFeatureViewModel: ObservableObject {
       @Published var feature: NewFeature?
       // 業務邏輯
   }
   ```

4. **View** (`Views/`)
   ```swift
   struct NewFeatureView: View {
       @StateObject var viewModel = NewFeatureViewModel()
       var body: some View {
           // UI 實現
       }
   }
   ```

### 調試技巧

```swift
// 啟用詳細日誌
print("[API] Request: \(endpoint)")
print("[Cache] Hit: \(chapterId)")
print("[Subtitle] Current: \(currentWord)")
```

## 性能優化

- ✅ ETag 緩存減少重複下載
- ✅ 章節列表和詳情分離緩存
- ✅ 音頻文件臨時緩存
- ✅ 字幕滾動性能優化（ScrollViewProxy）
- ✅ 波形按需生成

## 已知問題

1. **播放控制時間同步**: 已修復，使用穩定的 Timer 機制
2. **字幕滾動卡頓**: 已優化，使用 ScrollViewProxy
3. **音頻緩存策略**: 使用臨時目錄，避免存儲爆炸

## 未來規劃

- [ ] 播放速度調整
- [ ] 生詞本功能
- [ ] 離線下載管理
- [ ] 學習進度統計
- [ ] 多語言支持

## 許可證

MIT License

## 相關項目

- [Storytelling Backend](../storytelling-backend) - Python 後端服務
