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

## Prohibitions

- Never import `SwiftUI` or `UIKit` — display belongs in `Presentation`
- Never import from `Repositories`, `UseCases`, or `Domain` — dependency flows upward only
- Never define a protocol (`*Protocol`) outside of the `Protocols/` subdirectory
- Never convert DTOs to domain entities here — that belongs in `Repositories`
- Never add business logic (validation, cross-entity rules)
