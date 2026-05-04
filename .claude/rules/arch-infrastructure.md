---
paths:
  - 'Sources/Infrastructure/**/*.swift'
---

The lowest layer — the only place that may directly use persistence (SwiftData), media (Photos), network, or other OS-level APIs.

## Subdirectories

| Path | Role |
|------|------|
| `SwiftData/` | `SlideDataSource` — SwiftData-backed implementation |
| `SwiftData/DTO/` | `@Model` classes (`SlideModel`, `SlideshowModel`) — raw persistence schema |
| `Image/` | `ImageDataSource` — Photos framework access |
| `Image/DTO/` | Raw transport types (`ImageDTO`) returned from adapters |
| `Protocols/` | `*DataSourceProtocol` — contracts consumed by `Repositories` |

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation`, `SwiftData`, `Photos`, `CoreLocation`, `Network`, … | `SwiftUI`, `UIKit` |
| `Protocols/` (intra-layer) | `Repositories`, `UseCases`, `Domain` layer types |

> **Exception**: `TenSlideApp.swift` in `App/` may import `SwiftData` solely to pass `ModelContainer` to the SwiftUI environment.

## DTO placement

DTOs live in `*/DTO/` subdirectories and are either SwiftData `@Model` classes or plain `Sendable` structs. They are internal to this layer — the `Repositories` layer depends on them only through protocol return types.

```swift
// Good — DTO is internal; protocol exposes it as a return type
protocol SlideDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideModel]   // SlideModel is the DTO
}

// Bad — repository holds a concrete SwiftData model directly
final class SlideRepository {
    private let model: SlideModel   // NG: repositories work through protocols
}
```

## Adapter pattern

Each infrastructure capability is a `final class` implementing a protocol from `Protocols/`. No bare function exports.

```swift
// Good
final class SlideDataSource: SlideDataSourceProtocol {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }
    func fetchAll() async throws -> [SlideModel] { ... }
}

// Bad — standalone function bypasses DI and the protocol boundary
func fetchAllSlides(container: ModelContainer) async throws -> [SlideModel] { ... }
```

## SwiftData concurrency — `@ModelActor` + DTO

`ModelContext` is thread-bound. The correct Swift 6 approach is `@ModelActor actor`, which synthesizes `init(modelContainer:)` and pins all model access to one executor. Never wrap `ModelContext` in a `Mutex`.

Convert `@Model` instances to **Sendable DTO structs** inside the actor before returning across actor boundaries. `@Model` classes are non-Sendable and must not cross the actor boundary.

```swift
// Good — @ModelActor actor with DTO conversion
@ModelActor
actor SlideDataSource: SlideDataSourceProtocol {
    func fetchAll() throws -> [SlideDTO] {
        let descriptor = FetchDescriptor<SlideModel>()
        let models = try modelContext.fetch(descriptor)
        return models.map { SlideDTO(id: $0.id, order: $0.order) }
    }
}

// Bad — Mutex<ModelContext> is not thread-safe for SwiftData
final class SlideDataSource {
    private let context: Mutex<ModelContext>   // NG: use @ModelActor
}
```

DTO structs live in `SwiftData/DTO/` alongside `@Model` classes:
- `SlideModel` (`@Model`) — persistence schema, stays inside the actor
- `SlideDTO` (`Sendable struct`) — crosses actor boundaries, consumed by Repositories

## Blocking work offload

Synchronous CPU-bound work (file I/O, image decoding) must not block the current async executor. Use `Task.detached(priority:)` to offload.

```swift
// Good — decode off the cooperative pool
func loadImage(data: Data) async -> NSImage? {
    await Task.detached(priority: .userInitiated) {
        NSImage(data: data)
    }.value
}

// Bad — blocks the caller's executor
func loadImage(data: Data) -> NSImage? {
    NSImage(data: data)   // NG: synchronous decode on current thread
}
```

For `NSImage(data:)` specifically: decode in a detached task, then assign the result back on `@MainActor` where the ViewModel resides. Use an injectable decoder closure to keep testability.

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

## Prohibitions

- Never import `SwiftUI` or `UIKit` — display belongs in `Presentation`
- Never import from `Repositories`, `UseCases`, or `Domain` — dependency flows upward only
- Never define a protocol (`*Protocol`) outside of the `Protocols/` subdirectory
- Never convert DTOs to domain entities here — that belongs in `Repositories`
- Never add business logic (validation, cross-entity rules)
- Never wrap `ModelContext` in a `Mutex` — use `@ModelActor` actor
- Never return `@Model` classes across actor boundaries — convert to Sendable DTOs first
- Never use `PHAccessLevel.readOnly` — it does not exist
