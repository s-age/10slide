# DI Layer

## `Sources/DI/PresentationContainer.swift` (modified)

`makeSlideshowLibraryViewModel()` を追加する。

```swift
@MainActor
func makeSlideshowLibraryViewModel() -> SlideshowLibraryViewModel {
    SlideshowLibraryViewModel(fetchSlideshow: useCases.fetchSlideshow)
}
```

`fetchSlideshow` は `UseCaseContainer` に `FetchSlideshowUseCase` として定義済み。DI の接続だけが残タスク。

## `Sources/DI/UseCaseContainer.swift` (確認)

`FetchSlideshowUseCase` のインスタンスが `useCases.fetchSlideshow` として公開されていることを確認する。未公開の場合はプロパティを追加する。
