---
paths:
  - 'Sources/Repositories/**/*.swift'
---

Wraps the generic SwiftData store into domain-meaningful operations. Owns `@Model` types and query descriptors. Converts `@Model` instances → domain entities via transform closures. Never exposes `@Model` types outside this layer.

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
| `Foundation`, `SwiftData`, `Domain/Entities`, `Errors` | `SwiftUI`, `UIKit` |
| `Infrastructure/Protocols/` (`SwiftDataStoreProtocol`, etc.) | `Infrastructure` concrete classes directly |
| `Protocols/` (intra-layer) | `UseCases` — dependency flows upward only |

> `SwiftData` is allowed here because this layer owns `@Model` types, builds `FetchDescriptor`s, and writes `#Predicate` expressions. It never exposes these types to callers — only domain entities cross the layer boundary.

## Patterns

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

**Protocol placement** — every repository protocol lives in `Protocols/`, never in the implementation file

```swift
// Good — Protocols/SlideRepositoryProtocol.swift
protocol SlideRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slide]
    func save(_ slide: Slide, in slideshowID: UUID) async throws
    func delete(id: UUID) async throws
}
```

**Dependency injection** — inject `SwiftDataStoreProtocol`, not the concrete `SwiftDataStore`

```swift
// Good
final class SlideRepository: SlideRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    init(store: any SwiftDataStoreProtocol) {
        self.store = store
    }
}
```

## Prohibitions

- Never import `SwiftUI` or `UIKit`
- Never import from `UseCases` — dependency flows upward only
- Never add business logic (domain rules, cross-entity orchestration)
- Never define a protocol in an implementation file — protocols live in `Protocols/`
- Never return `@Model` types from protocol methods — always return domain entities
- Never place `@Model` types outside `Models/` within this layer
