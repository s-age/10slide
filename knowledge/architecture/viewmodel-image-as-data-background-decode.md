---
type: decision
context: when a Presentation-layer ViewModel needs to expose an image loaded from a use case
keywords: [ViewModel, NSImage, Data, AppKit, background-decode, Task.detached, arch-presentation]
---

## What

`arch-presentation.md` restricts `AppKit` from the ViewModel import allowlist. Holding
`NSImage?` in a ViewModel requires `import AppKit`, causing a SwiftLint violation. Moving
`NSImage(data:)` conversion into the View body avoids the violation but blocks the main
thread on synchronous decode, causing frame drops.

## Do

ViewModel holds `Data?`; the View owns `@State private var decodedImage: NSImage?` and
decodes asynchronously via `.task(id:)` + `Task.detached`:

```swift
// ViewModel — no AppKit import required
private(set) var currentImage: Data?

// View
@State private var decodedImage: NSImage?

.task(id: viewModel.currentImage) {
    guard let data = viewModel.currentImage else { decodedImage = nil; return }
    decodedImage = await Task.detached(priority: .userInitiated) {
        NSImage(data: data)
    }.value
}

@ViewBuilder
private var slideImage: some View {
    if let nsImage = decodedImage {
        Image(nsImage: nsImage).resizable().scaledToFit()
    } else {
        Color.black
    }
}
```

Benefits: ViewModel stays AppKit-free (allowlist compliant), decode runs off the main
thread, and `.task(id:)` auto-cancels the previous decode when `data` changes.

## Don't

- Hold `NSImage?` in a ViewModel — `import AppKit` is required, violating the
  presentation-layer allowlist and triggering SwiftLint errors
- Call `NSImage(data:)` synchronously inside View body — blocks the main thread and
  causes frame drops during slideshow playback
- Inject `imageDecoder: @Sendable (Data) -> NSImage?` into the ViewModel — still pulls
  AppKit types into the ViewModel layer
