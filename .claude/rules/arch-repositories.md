---
paths:
  - 'Sources/Repositories/**/*.swift'
---

Bridges Infrastructure data sources and Domain entities. Two variants exist:

- **SwiftData repositories** — own `@Model` types, build `FetchDescriptor`s and `#Predicate` expressions, convert `@Model` → entity via transform closures. Never expose `@Model` types outside this layer.
- **DataSource repositories** — delegate to Infrastructure `DataSourceProtocol`s, convert DTO ↔ entity. No `@Model` or `SwiftData` dependency.

## Directory layout

```
Repositories/
├── Models/          # @Model classes (SwiftData persistence schema)
├── Implementations/ # Concrete classes conforming to protocols
└── Protocols/       # *RepositoryProtocol contracts consumed by UseCases
```

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation`, `Domain/Entities`, `Errors` | `SwiftUI`, `UIKit` |
| `SwiftData` (SwiftData repositories only — for `@Model`, `FetchDescriptor`, `#Predicate`) | `Infrastructure` concrete classes directly |
| `Infrastructure/Protocols/` (`SwiftDataStoreProtocol`, `ConfigDataSourceProtocol`, `ImageDataSourceProtocol`, etc.) | `UseCases` — dependency flows upward only |
| `Protocols/` (intra-layer) | |

> `SwiftData` is allowed in SwiftData repositories because they own `@Model` types, build `FetchDescriptor`s, and write `#Predicate` expressions. DataSource repositories do not import `SwiftData`. Neither variant exposes infrastructure types to callers — only domain entities cross the layer boundary.

## Patterns

### SwiftData repositories

**fetch with transform** — build the descriptor here; pass a transform closure to stay inside the actor boundary

```swift
// Good — @Model stays inside the store actor; entity is returned
func fetchAll() async throws -> [Slide] {
    try await store.fetch(FetchDescriptor<SlideModel>()) {
        Slide(id: $0.id, localIdentifier: $0.localIdentifier,
              order: $0.order, duration: $0.duration, title: $0.title)
    }
}

// Bad — leaking @Model to the caller
func fetchAll() async throws -> [SlideModel] { ... }   // NG: @Model must not cross this boundary
```

**write for mutations** — upsert and other multi-step writes use `store.write(_:)` to execute atomically inside the actor

```swift
// Good — query building, mutation, and save happen in one actor call
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id
    try await store.write { context in
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.name = slideshow.name
            // ...
        } else {
            context.insert(SlideshowModel(...))
        }
        try context.save()
    }
}
```

**delete** — use `store.delete(_:where:)` for single-predicate deletes (auto-saves)

```swift
func delete(id: UUID) async throws {
    try await store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
}
```

### DataSource repositories

**DTO conversion** — load from DataSource, convert DTO → entity; convert entity → DTO for save

```swift
// Good — DTO stays inside the repository; entity is returned
func load() async throws -> SlideshowConfig {
    guard let dto = try await configDataSource.load() else {
        return .default
    }
    return SlideshowConfig(
        duration: SlideDuration(rawValue: dto.duration) ?? .five,
        transition: TransitionType(rawValue: dto.transition) ?? .default,
        loop: dto.loop
    )
}

func save(_ config: SlideshowConfig) async throws {
    let dto = ConfigDTO(
        duration: config.duration.rawValue,
        transition: config.transition.rawValue,
        loop: config.loop
    )
    try await configDataSource.save(dto)
}
```

**delegation** — thin pass-through to DataSource with minimal DTO extraction

```swift
// Good — extracts data from DTO, delegates the rest
func fetchImageData(localIdentifier: String) async throws -> Data {
    let dto = try await imageDataSource.fetchImage(localIdentifier: localIdentifier)
    return dto.data
}

func fetchAllIdentifiers() async throws -> [String] {
    try await imageDataSource.fetchAllIdentifiers()
}
```

### Common patterns (both variants)

**Protocol placement** — every repository protocol lives in `Protocols/`, never in the implementation file

```swift
// Good — Protocols/SlideRepositoryProtocol.swift
protocol SlideRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slide]
    func save(_ slide: Slide, in slideshowID: UUID) async throws
    func delete(id: UUID) async throws
}
```

**Dependency injection** — inject Infrastructure protocols, not concrete classes

```swift
// Good — SwiftData repository
final class SlideRepository: SlideRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol
    init(store: any SwiftDataStoreProtocol) { self.store = store }
}

// Good — DataSource repository
final class ConfigRepository: ConfigRepositoryProtocol {
    private let configDataSource: any ConfigDataSourceProtocol
    init(configDataSource: any ConfigDataSourceProtocol) { self.configDataSource = configDataSource }
}
```

## Prohibitions

- Never import `SwiftUI` or `UIKit`
- Never import from `UseCases` — dependency flows upward only
- Never add business logic (domain rules, cross-entity orchestration)
- Never define a protocol in an implementation file — protocols live in `Protocols/`
- Never return `@Model` types from protocol methods — always return domain entities
- Never place `@Model` types outside `Models/` within this layer
- Never import `SwiftData` in a DataSource repository — only SwiftData repositories use it
