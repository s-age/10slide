# Swift 6 SwiftData Concurrency: @ModelActor Pattern

> **Supersedes earlier advice** about `Mutex<ModelContext>`. The correct Swift 6 approach is `@ModelActor`.

## Problem

SwiftData's `ModelContext` is thread-bound (like `NSManagedObjectContext`). Under Swift 6 strict concurrency:

1. `Mutex<ModelContext>` serializes access but does NOT guarantee the same thread — `ModelContext` faults and relationship traversal can still crash.
2. `@Model` classes are non-Sendable. Returning them from an actor method crosses the actor boundary and triggers Swift 6 compiler errors (or unsafe `@unchecked Sendable`).

## Correct Pattern: `@ModelActor actor`

```swift
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    // modelContext and modelExecutor are synthesized by @ModelActor
    // All methods run on the actor's executor (same thread as the ModelContainer)

    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))   // convert @Model → Sendable struct INSIDE the actor
    }

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        SlideshowDTO(id: model.id, name: model.name, ...)
    }
}
```

Key rules:
- Use `actor` keyword (not `final class`) — `@ModelActor` requires it
- `init(modelContainer:)` is synthesized — do NOT write your own
- Convert `@Model` → Sendable DTO **inside** the actor executor before returning
- Protocol declares `async throws` even though actor methods are sync — Swift wraps them

## DTO Layer Pattern

Define plain Sendable structs in `Infrastructure/SwiftData/DTO/`:

```swift
struct SlideshowDTO: Sendable {
    let id: UUID; let name: String; let slides: [SlideDTO]; ...
}
struct SlideDTO: Sendable {
    let id: UUID; let localIdentifier: String; let order: Int; ...
}
```

Protocol signatures use DTO types, not `@Model` types:

```swift
protocol SlideshowDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideshowDTO]
    func fetch(id: UUID) async throws -> SlideshowDTO?
    func save(_ dto: SlideshowDTO) async throws
    func delete(id: UUID) async throws
}
```

## Why Not `Mutex<ModelContext>`?

`Mutex` serializes calls but the underlying `ModelContext` still expects to be used on a single thread. Relationship faults (lazy-loaded `@Relationship` properties) are triggered on whatever thread touches the model — if that thread differs from the context's home thread, it silently corrupts data or crashes. `@ModelActor` binds all model access to one actor executor, solving this properly.

## `@unchecked Sendable` on `@Model` Classes — Don't

Adding `@unchecked Sendable` to `SlideshowModel` / `SlideModel` to silence compiler errors is wrong:
- Swift 6 may emit "redundant conformance" warnings (the `@Model` macro already synthesizes it in some toolchain versions)
- Even if it compiles, accessing `@Model` properties outside the actor executor that owns the `ModelContext` is undefined behaviour

The DTO pattern is the only clean solution.

## References

- `Sources/Infrastructure/SwiftData/SlideshowDataSource.swift`
- `Sources/Infrastructure/SwiftData/DTO/SlideshowDTO.swift`
- `Sources/Infrastructure/SwiftData/DTO/SlideDTO.swift`
