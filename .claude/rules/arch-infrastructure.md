---
paths:
  - 'Sources/Infrastructure/**/*.swift'
---

The lowest layer — the only place that may directly use persistence (SwiftData), media (Photos), network, or other OS-level APIs.

## Subdirectories

| Path | Role |
|------|------|
| `SwiftData/` | `SwiftDataStore` — generic `@ModelActor` store; executes fetch/delete/write on `ModelContext` |
| `Image/` | `ImageDataSource` — Photos framework access |
| `Image/DTO/` | Raw transport types (`ImageDTO`) returned from adapters |
| `Protocols/` | `*Protocol` contracts consumed by `Repositories` |

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation`, `SwiftData`, `Photos`, `CoreLocation`, `Network`, `ImageIO`, `CoreGraphics`, …, `Errors` | `SwiftUI`, `UIKit`, `AppKit` |
| `Protocols/` (intra-layer) | `Repositories`, `UseCases`, `Domain` layer types |

> **Exception**: `TenSlideApp.swift` in `App/` may import `SwiftData` solely to pass `ModelContainer` to the SwiftUI environment.

## SwiftData concurrency — generic `@ModelActor` store

`ModelContext` is thread-bound. The correct Swift 6 approach is `@ModelActor actor`, which synthesizes `init(modelContainer:)` and pins all model access to one executor. Never wrap `ModelContext` in a `Mutex`.

`SwiftDataStore` is a thin generic actor that exposes three operations. `@Model` types live in `Repositories/Models/` — Infra works with them only through generic `PersistentModel` constraints.

```swift
// Good — generic actor; Repositories supply the concrete T and the transform
@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol {
    func fetch<T: PersistentModel, R: Sendable>(
        _ descriptor: FetchDescriptor<T>,
        transform: @Sendable (T) throws -> R
    ) throws -> [R] {
        try modelContext.fetch(descriptor).map(transform)
    }

    func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws {
        try modelContext.delete(model: type, where: predicate)
        try modelContext.save()
    }

    func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
        try work(modelContext)
    }
}

// Bad — Mutex<ModelContext> is not thread-safe for SwiftData
final class SlideDataSource {
    private let context: Mutex<ModelContext>   // NG: use @ModelActor
}
```

## Adapter pattern

Each infrastructure capability implements a protocol from `Protocols/`. No bare function exports.

```swift
// Good — protocol-backed actor in SwiftData/
@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol { ... }

// Bad — standalone function bypasses DI and the protocol boundary
func fetchAllSlides(container: ModelContainer) async throws -> [Slide] { ... }
```

## Blocking work offload

Synchronous CPU-bound work (file I/O, image decoding) must not block the current async executor. Use `Task.detached(priority:)` to offload.

```swift
// Good — thumbnail generation off the cooperative pool (ImageIO, no AppKit)
func makeThumbnail(from data: Data) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceThumbnailMaxPixelSize: 200,
                  kCGImageSourceCreateThumbnailFromImageAlways: true
              ] as CFDictionary)
        else { throw ImageDataSourceError.dataUnavailable }
        let dest = NSMutableData()
        let imageDestination = CGImageDestinationCreateWithData(dest, "public.jpeg" as CFString, 1, nil)!
        CGImageDestinationAddImage(imageDestination, cgImage, nil)
        CGImageDestinationFinalize(imageDestination)
        return dest as Data
    }.value
}

// Bad — blocks the caller's executor
func makeThumbnail(from data: Data) throws -> Data {
    // NG: synchronous CPU work on current thread
}
```

## Photos framework

**Authorization**: Always use `PHPhotoLibrary.requestAuthorization(for:)` — it shows the permission dialog on first launch and returns the cached status on subsequent calls. Calling `authorizationStatus(for:)` alone returns `.notDetermined` on first launch and does not trigger the dialog. Ensure `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` is set in build settings.

```swift
// Good
let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

// Bad — returns .notDetermined on first launch, no dialog shown
let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
```

**Access level**: `PHAccessLevel` has only two cases: `.addOnly` and `.readWrite`. There is **no `.readOnly` case** — it does not exist in the API. For read access, use `.readWrite`.

**Fetch limits**: `PHAsset.fetchAssets()` can return thousands of results. Always set `PHFetchOptions.fetchLimit` (e.g. 500–1000) to cap enumeration and prevent memory pressure.

```swift
let options = PHFetchOptions()
options.fetchLimit = 500
let assets = PHAsset.fetchAssets(with: .image, options: options)
```

**Continuation safety**: Never use `deliveryMode = .opportunistic` inside `withCheckedThrowingContinuation`. `.opportunistic` fires the callback twice (low-quality then high-quality), which causes a crash on the second `resume`. If only the low-quality version is available and you skip it with `if isDegraded { return }`, the continuation is never resumed and the task hangs forever (memory leak). Always use `.highQualityFormat` to guarantee exactly one callback.

```swift
// Good — single callback guaranteed
let options = PHImageRequestOptions()
options.deliveryMode = .highQualityFormat
let data: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
        if let data { continuation.resume(returning: data) }
        else { continuation.resume(throwing: ImageDataSourceError.dataUnavailable) }
    }
}

// Bad — crashes or hangs
options.deliveryMode = .opportunistic   // NG: callback fires twice → double resume crash
```

**Image data vs NSImage**: `requestImage(for:targetSize:contentMode:options:resultHandler:)` returns `NSImage` on macOS, which requires `AppKit`. Use `requestImageDataAndOrientation` instead — it returns raw `Data` with no UI framework dependency. Resize using `CGImageSourceCreateThumbnailAtIndex` (ImageIO) in a detached task.

## Prohibitions

- Never import `SwiftUI`, `UIKit`, or `AppKit` — display belongs in `Presentation`
- Never import from `Repositories`, `UseCases`, or `Domain` — dependency flows upward only
- Never define a protocol (`*Protocol`) outside of the `Protocols/` subdirectory
- Never convert DTOs to domain entities here — that belongs in `Repositories`
- Never add business logic (validation, cross-entity rules)
- Never wrap `ModelContext` in a `Mutex` — use `@ModelActor` actor
- Never define domain-specific query logic here — `FetchDescriptor` and `#Predicate` belong in `Repositories`
- Never use `PHAccessLevel.readOnly` — it does not exist
