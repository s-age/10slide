# Presentation Layer

## `Sources/Presentation/Views/ContentView.swift` (modified)

`.toolbar` の ToolbarItem を削除し、`onBack` クロージャを `SlideshowPlayerView` に渡す。

```swift
var body: some View {
    if let slideshow = selectedSlideshow {
        SlideshowPlayerView(
            viewModel: makeSlideshowPlayerViewModel(slideshow),
            onBack: { selectedSlideshow = nil }
        )
        // .toolbar { ToolbarItem { Button("Back") { ... } } } を削除
    } else {
        LibraryPickerView(...)
    }
}
```

## `Sources/Presentation/Views/SlideshowPlayerView.swift` (modified)

`onBack: () -> Void` パラメータを追加。Back ボタンを `.overlay(alignment: .topTrailing)` で配置する。`FilmstripView` に `duration` / `transition` を渡す。

```swift
struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            // ... slideImage (変更なし) ...

            if viewModel.showFilmstrip {
                FilmstripView(
                    slides: viewModel.slideshow.slides,
                    currentIndex: viewModel.currentIndex,
                    duration: viewModel.slideshow.config.duration,
                    transition: viewModel.slideshow.config.transition,
                    onSelect: { index in Task { await viewModel.jumpTo(index: index) } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.showFilmstrip {
                Button(action: onBack) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.4))
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .padding(12)
                .transition(.opacity)
            }
        }
        // .animation は既存のものをそのまま維持
    }
}
```

## `Sources/Presentation/Views/FilmstripView.swift` (modified)

`duration: SlideDuration` と `transition: TransitionType` を追加。上部に設定表示バーを追加し、全体の高さを `80 → 104` に調整する。

```swift
struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let duration: SlideDuration
    let transition: TransitionType
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 設定表示バー
            HStack {
                Label(duration.displayLabel, systemImage: "timer")
                Spacer()
                Label(transition.rawValue.capitalized, systemImage: "photo.on.rectangle.angled")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)

            Divider().opacity(0.3)

            // サムネイル（既存）
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(slides.indices, id: \.self) { index in
                        thumbnailCell(index: index)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 80)
        }
        .background(.ultraThinMaterial)
    }
    // thumbnailCell は変更なし
}
```

### 注意点

- `SlideshowConfig.duration` は `SlideDuration` 型。`displayLabel` プロパティがすでに定義されている。
- `TransitionType.rawValue` は英小文字 (`none`, `fade`, `slide`, `dissolve`)。`.capitalized` で先頭大文字化して表示。
- height を `80 → 104` に変えると `SlideshowPlayerView` 側の `FilmstripView` の frame は変更不要（VStack 内のサムネイル高さは 80 を維持するため）。
