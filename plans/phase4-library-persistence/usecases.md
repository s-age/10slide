# UseCases Layer

## `Sources/UseCases/CreateSlideshowUseCase.swift` (modified)

作成後に `SlideshowRepository.save(_:)` を呼び出して SwiftData に永続化する。

```swift
func execute(name: String, identifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
    let slideshow = buildSlideshow(name: name, identifiers: identifiers, config: config)
    try await slideshowRepository.save(slideshow)  // ← 追加
    return slideshow
}
```

`SlideshowRepositoryProtocol` に `save(_:)` メソッドが存在することを確認する。なければ追加する。

## `Sources/UseCases/FetchSlideshowUseCase.swift` (変更なし)

すでに実装済み。DI への接続だけが残タスク。
