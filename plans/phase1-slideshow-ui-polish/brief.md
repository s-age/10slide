# Goal

スライドショー再生画面の UI を 3 点改善する。

1. ヘッダ（macOS ツールバー）を全画面モードで非表示にする
2. Back ボタンをウインドウ右上にアイコンでフロート表示し、フィルムストリップと同タイミングで隠す
3. duration / transition の情報をフィルムストリップバー内に表示する

# Key Design Decisions

- 1 と 2 は同じ変更で解決する: `ContentView` の `.toolbar` Back ボタンを削除し、`SlideshowPlayerView` の ZStack overlay として Back ボタンを追加する。toolbar がなくなることで全画面時のヘッダも自動的に消える。
- Back ボタンの表示/非表示は `viewModel.showFilmstrip` を流用。追加の状態変数は不要。
- フィルムストリップバーに duration / transition を表示するために `FilmstripView` に 2 つのパラメータを追加する。レイアウトは既存の `.frame(height: 80)` を調整して吸収する。

# Scope

| ファイル | 変更種別 |
|---|---|
| `Sources/Presentation/Views/ContentView.swift` | Back ボタンの ToolbarItem を削除し `onBack` クロージャを渡す |
| `Sources/Presentation/Views/SlideshowPlayerView.swift` | Back オーバーレイ追加、FilmstripView の呼び出しにパラメータ追加 |
| `Sources/Presentation/Views/FilmstripView.swift` | duration / transition 表示エリアを上部に追加 |
| `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` | 変更なし |
| `Sources/Domain/Entities/SlideshowConfig.swift` | 変更なし |
