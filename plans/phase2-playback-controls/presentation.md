# Presentation Layer

## `Sources/Presentation/Views/FilmstripView.swift` (modified)

Phase 1 で追加した設定バーにコントロールボタンを組み込む。ViewModel のメソッドを直接呼ぶのではなく、クロージャで受け取る（FilmstripView を ViewModel に依存させない）。

```swift
struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let duration: SlideDuration
    let transition: TransitionType
    let isPlaying: Bool
    let onSelect: (Int) -> Void
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 設定バー + コントロール
            HStack {
                Label(duration.displayLabel, systemImage: "timer")

                Spacer()

                // 再生コントロール
                HStack(spacing: 16) {
                    Button(action: onPrevious) {
                        Image(systemName: "backward.fill")
                    }
                    Button(action: onPlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    Button(action: onNext) {
                        Image(systemName: "forward.fill")
                    }
                }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.primary)

                Spacer()

                Label(transition.rawValue.capitalized, systemImage: "photo.on.rectangle.angled")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            // サムネイル（変更なし）
            ...
        }
    }
}
```

## `Sources/Presentation/Views/SlideshowPlayerView.swift` (modified)

FilmstripView の新しいクロージャを接続し、キーボードショートカットを追加する。

```swift
// FilmstripView 呼び出し側
FilmstripView(
    slides: viewModel.slideshow.slides,
    currentIndex: viewModel.currentIndex,
    duration: viewModel.slideshow.config.duration,
    transition: viewModel.slideshow.config.transition,
    isPlaying: viewModel.isPlaying,
    onSelect: { index in Task { await viewModel.jumpTo(index: index) } },
    onPrevious: { Task { await viewModel.previous() } },
    onPlayPause: {
        if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
    },
    onNext: { Task { await viewModel.next() } }
)

// キーボードショートカット（ZStack または body 直下）
.onKeyPress(.space) {
    if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
    return .handled
}
.onKeyPress(.leftArrow) {
    Task { await viewModel.previous() }
    return .handled
}
.onKeyPress(.rightArrow) {
    Task { await viewModel.next() }
    return .handled
}
```

### 注意点

- `onKeyPress` は macOS 14+ で利用可能。ターゲットが macOS 26 であるため問題なし。
- `onKeyPress` はフォーカスが当たっているビューにのみ届く。`SlideshowPlayerView` に `.focusable()` を追加するか、`.onAppear { NSApp.mainWindow?.makeFirstResponder(nil) }` でウインドウレベルで受け取る方法を検討する。
- `isPlaying` を `FilmstripView` に渡すことでアイコンの切り替え（▶ / ⏸）を実現する。ViewModel への参照は持たせない。
