---
type: gotcha
context: when decoding image data for display in a @MainActor ViewModel
keywords: [NSImage, decoding, main thread, Task.detached, @MainActor, performance, injectable]
---

## What

`NSImage(data:)` decodes JPEG/PNG synchronously and is CPU-intensive. Calling it directly in a
`@MainActor` ViewModel or View causes frame drops. The pattern is: inject the decoder as a
`@Sendable` closure, decode in a detached task, assign the result back on `@MainActor`.

After `await Task.detached {...}.value` the caller resumes on its own actor (the `@MainActor`-
isolated ViewModel), so the assignment `currentImage = ...` is automatically on the main actor.

See `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` and
`Tests/PresentationTests/SlideshowPlayerViewModelTests.swift`.

## Do

Inject the decoder and use `Task.detached`:

```swift
private let imageDecoder: @Sendable (Data) -> NSImage?

init(..., imageDecoder: @Sendable @escaping (Data) -> NSImage? = { NSImage(data: $0) }) {
    self.imageDecoder = imageDecoder
}

func loadCurrentImage() async {
    let data = try await loadSlideImageUseCase.execute(...)
    let decode = imageDecoder           // capture locally — must be Sendable
    currentImage = await Task.detached(priority: .userInitiated) {
        decode(data)
    }.value
}
```

In tests, pass a stub that avoids real image data:
```swift
sut = SlideshowPlayerViewModel(..., imageDecoder: { _ in NSImage(size: .init(width: 1, height: 1)) })
```

## Don't

- Don't call `NSImage(data:)` directly inside a `@MainActor` function.
- Don't put `NSImage(data:)` in a View's `body` — decode upstream in the ViewModel.
- Don't capture a non-Sendable `self` into `Task.detached`; copy needed values into locals first.
