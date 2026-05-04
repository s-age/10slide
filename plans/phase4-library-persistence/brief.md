# Goal

スライドショーをライブラリとして保存できるようにし、初期画面を 7:3 分割レイアウトに再設計する。

- 左 70%: 選択中ディレクトリの画像サムネイル（ソースパネル）
- 右 30%: 保存済みライブラリ一覧（ライブラリパネル）

# Key Design Decisions

- SwiftData の `SlideshowModel` / `SlideshowDataSource` はすでに実装されている。`FetchSlideshowUseCase` も存在する。残作業は「UI に接続すること」と「CreateSlideshow 時に永続化すること」。
- `CreateSlideshowUseCase` はすでにスライドショーを作成するが、保存していない場合は `SlideshowRepository.save(_:)` を呼ぶように修正する。
- 初期画面は新しい `HomeView` として実装し、`ContentView` から参照する。既存の `LibraryPickerView` はソースパネル（左側）として流用する。
- ライブラリパネルはシンプルなリスト表示。選択した既存スライドショーは即座に再生モードに遷移する。
- 7:3 分割は `HSplitView` で実装。最小幅を設定し、ユーザーがリサイズ可能にする。

# Dependency

Phase 3 完了後に着手する（ファイルシステムベースのデータソースが前提）。

# Scope

| ファイル | 変更種別 |
|---|---|
| `Sources/Presentation/Views/HomeView.swift` | 新規（7:3 分割レイアウト） |
| `Sources/Presentation/Views/SlideshowLibraryPanel.swift` | 新規（ライブラリ一覧パネル） |
| `Sources/Presentation/Views/ContentView.swift` | `LibraryPickerView` → `HomeView` に差し替え |
| `Sources/Presentation/ViewModels/SlideshowLibraryViewModel.swift` | 新規 |
| `Sources/UseCases/CreateSlideshowUseCase.swift` | `save(_:)` 呼び出しを追加 |
| `Sources/DI/PresentationContainer.swift` | `makeSlideshowLibraryViewModel()` 追加 |
