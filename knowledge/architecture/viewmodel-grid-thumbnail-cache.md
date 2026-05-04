---
type: discovery
context: when rendering a SwiftUI grid or list where each cell loads its own thumbnail
keywords: [NSImage, decode, grid, thumbnail, Task.detached, decodedImages, View state, cache, off-main, arch-presentation]
---

## What

When a grid or list loads per-cell thumbnails, calling `NSImage(data:)` synchronously
during layout causes scroll jank. The pattern: ViewModel holds `[String: Data]`, View
holds `[String: NSImage]` decoded off-main via `Task.detached`. This also keeps the
ViewModel AppKit-free, satisfying the arch-presentation import allowlist.

## Do

Hold decoded images in View `@State`; decode asynchronously inside the cell's
`.task(id:)` modifier:

```swift
// In the parent View
@State private var decodedImages: [String: NSImage] = [:]

// In each cell's .task(id:) modifier
.task(id: identifier) {
    await thumbnailViewModel.loadThumbnail(identifier: identifier)
    if let data = thumbnailViewModel.thumbnails[identifier] {
        decodedImages[identifier] = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
    }
}

// Pass pre-decoded image to the cell — no synchronous decode during layout
PhotoCell(image: decodedImages[identifier], isSelected: ...)
```

The ViewModel exposes `thumbnails: [String: Data]` only. Decoded `NSImage` values are
cached in View state; `.task(id:)` auto-cancels the previous decode when the identifier
changes. The same pattern applies to full-size images (see `SlideshowPlayerView`).

## Don't

- Don't call `NSImage(data:)` synchronously in `View.body` or in a cell renderer —
  blocks the main thread, causing jank during scroll
- Don't hold `[String: NSImage]` in the ViewModel — `import AppKit` violates the
  arch-presentation allowlist and triggers SwiftLint errors
- Don't decode on `@MainActor` even outside `body` — use `Task.detached` so work truly
  runs off the main thread
