# Goal

スライドショー再生画面に一時停止 / 再開、前へ / 次へのコントロールを追加する。

# Key Design Decisions

- `SlideshowPlayerViewModel` にはすでに `pause()`, `play()`, `next()`, `previous()`, `isPlaying` が実装されている。ViewModel の変更は不要。
- コントロールは Phase 1 で整備したフィルムストリップバー内（duration / transition 表示の隣）に統合する。フィルムストリップと同じタイミングで表示/非表示になるため、別途の表示制御は不要。
- キーボードショートカットを追加する: Space = 再生 / 一時停止、← = 前へ、→ = 次へ。

# Dependency

Phase 1 完了後に着手する（FilmstripView の設定バーが配置済みであることを前提とする）。

# Scope

| ファイル | 変更種別 |
|---|---|
| `Sources/Presentation/Views/FilmstripView.swift` | コントロールボタンを設定バーに追加 |
| `Sources/Presentation/Views/SlideshowPlayerView.swift` | キーボードショートカット追加 |
| `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` | 変更なし |
