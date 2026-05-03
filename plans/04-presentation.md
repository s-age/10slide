# 04 — Presentation

## 画面構成

```
LibraryPickerView → SlideshowPlayerView
                         └── FilmstripView（下部オーバーレイ）
```

---

## LibraryPickerView / ViewModel

写真ライブラリから画像を選択し、スライドショーを作成する画面。

### ViewModel

```swift
// Sources/Presentation/ViewModels/LibraryPickerViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class LibraryPickerViewModel {
    private(set) var identifiers: [String] = []
    var selectedIdentifiers: Set<String> = []
    var slideshowName: String = ""
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchLibrary: FetchLibraryUseCase
    private let createSlideshow: CreateSlideshowUseCase

    init(
        fetchLibrary: FetchLibraryUseCase,
        createSlideshow: CreateSlideshowUseCase
    ) {
        self.fetchLibrary = fetchLibrary
        self.createSlideshow = createSlideshow
    }

    /// ライブラリから identifier 一覧を取得
    func loadLibrary() async { ... }

    /// 選択された写真でスライドショーを作成、作成された Slideshow を返す
    func createSlideshow() async -> Slideshow? { ... }
}
```

### View

```swift
// Sources/Presentation/Views/LibraryPickerView.swift
import SwiftUI

struct LibraryPickerView: View {
    @State private var viewModel: LibraryPickerViewModel
    var onSlideshowCreated: (Slideshow) -> Void

    init(viewModel: LibraryPickerViewModel, onSlideshowCreated: @escaping (Slideshow) -> Void) { ... }

    var body: some View {
        // - グリッドで写真サムネイル表示
        // - タップで選択/解除
        // - 「作成」ボタンで createSlideshow() 呼び出し
        ...
    }
}
```

---

## SlideshowPlayerView / ViewModel

スライドショー再生画面。フルスクリーン表示 + 下部フィルムストリップ。

### ViewModel

```swift
// Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift
import Foundation
import Observation

@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private(set) var slideshow: Slideshow
    private(set) var currentIndex: Int = 0
    private(set) var currentImageData: Data?
    private(set) var isPlaying: Bool = false
    private(set) var showFilmstrip: Bool = true

    private let loadSlideImage: LoadSlideImageUseCase
    private var timerTask: Task<Void, Never>?
    private var hideFilmstripTask: Task<Void, Never>?

    init(slideshow: Slideshow, loadSlideImage: LoadSlideImageUseCase) {
        self.slideshow = slideshow
        self.loadSlideImage = loadSlideImage
    }

    // MARK: - 再生制御

    /// 再生開始。タイマーで自動送り。
    func play() { ... }

    /// 一時停止
    func pause() { ... }

    /// 指定インデックスへジャンプ（フィルムストリップからのタップ用）
    func jumpTo(index: Int) async { ... }

    /// 次のスライドへ。ループ設定に応じて先頭に戻る。
    func next() async { ... }

    /// 前のスライドへ
    func previous() async { ... }

    // MARK: - 画像読み込み

    /// 現在のスライドの画像データを取得
    func loadCurrentImage() async { ... }

    // MARK: - フィルムストリップ表示制御

    /// ユーザー操作時に呼ばれる。フィルムストリップを表示し、数秒後に非表示にする。
    func userDidInteract() { ... }

    /// フィルムストリップを即座に表示（ホバー / タップ用）
    func showFilmstripOverlay() { ... }
}
```

### 再生タイマーの仕様

```
1. play() 呼び出し → isPlaying = true
2. Task で currentSlide.duration 秒待機
3. next() で次スライドへ（ループ判定は slideshow.config.loop を参照）
4. pause() または画面離脱で timerTask.cancel()
```

### View

```swift
// Sources/Presentation/Views/SlideshowPlayerView.swift
import SwiftUI

struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel

    init(viewModel: SlideshowPlayerViewModel) { ... }

    var body: some View {
        ZStack {
            // メイン: 現在スライドの画像（フルスクリーン）
            // トランジションは slideshow.config.transition に応じて SwiftUI .transition() で切替
            // 下部オーバーレイ: FilmstripView
        }
        .onTapGesture { viewModel.userDidInteract() }
    }
}
```

---

## FilmstripView

下部に表示されるスライドサムネイル一覧。未操作数秒で非表示、タップ/ホバーで再表示。

```swift
// Sources/Presentation/Views/FilmstripView.swift
import SwiftUI

struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        // 横スクロール ScrollView
        // 各スライドのサムネイル（小さい正方形）
        // currentIndex のサムネイルにハイライト枠
        // タップで onSelect(index) を呼ぶ
        ...
    }
}
```

### フィルムストリップ表示/非表示の仕様

```
1. 初期状態: 表示
2. 再生開始から 3 秒操作なし → withAnimation で非表示
3. 画面タップ or ホバー → 再表示 + タイマーリセット
4. 一時停止中 → 常時表示
```

---

## DI 配線（PresentationContainer への追加）

```swift
// Sources/DI/PresentationContainer.swift
final class PresentationContainer {
    private let useCases: UseCaseContainer

    init(useCases: UseCaseContainer) {
        self.useCases = useCases
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        LibraryPickerViewModel(
            fetchLibrary: useCases.fetchLibrary,
            createSlideshow: useCases.createSlideshow
        )
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: Slideshow) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(
            slideshow: slideshow,
            loadSlideImage: useCases.loadSlideImage
        )
    }
}
```

---

## ファイル構成

```
Sources/Presentation/
├── ViewModels/
│   ├── LibraryPickerViewModel.swift
│   └── SlideshowPlayerViewModel.swift
└── Views/
    ├── LibraryPickerView.swift
    ├── SlideshowPlayerView.swift
    └── FilmstripView.swift
```
