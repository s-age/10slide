# NSImage Decoding Must Be Off the Main Thread

## Problem

`NSImage(data:)` performs JPEG/PNG decoding synchronously and can be expensive. Calling it directly in a ViewModel or View that runs on `@MainActor` causes frame drops.

## Pattern: Task.detached + Injectable Decoder

Decode in a detached task (not `.userInitiated` on the main actor) and assign the result back on the main actor:

```swift
@Observable
final class SlideshowPlayerViewModel {
    var currentImage: NSImage?

    private let imageDecoder: @Sendable (Data) -> NSImage?

    init(..., imageDecoder: @Sendable @escaping (Data) -> NSImage? = { NSImage(data: $0) }) {
        self.imageDecoder = imageDecoder
    }

    func loadCurrentImage() async {
        guard let slide = currentSlide else { currentImage = nil; return }
        do {
            let data = try await loadSlideImageUseCase.execute(localIdentifier: slide.localIdentifier)
            let decode = imageDecoder   // capture locally — closures must be Sendable
            currentImage = await Task.detached(priority: .userInitiated) {
                decode(data)
            }.value
        } catch {
            currentImage = nil
        }
    }
}
```

The assigned `currentImage` is already back on `@MainActor` because `await Task.detached {...}.value`
resumes on the caller's actor (the `@MainActor`-isolated ViewModel).

## Testability

The injectable `imageDecoder` closure avoids needing real image data in tests:

```swift
sut = SlideshowPlayerViewModel(
    ...,
    imageDecoder: { _ in NSImage(size: NSSize(width: 1, height: 1)) }
)
```

## View Side

In the View, consume `viewModel.currentImage` directly — no `NSImage(data:)` in the view body:

```swift
if let image = viewModel.currentImage {
    Image(nsImage: image).resizable()
}
```

## References

- `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift`
- `Tests/PresentationTests/SlideshowPlayerViewModelTests.swift`
