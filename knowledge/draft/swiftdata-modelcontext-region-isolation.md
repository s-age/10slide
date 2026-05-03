# SwiftData ModelContext + Swift 6 region isolation

## Problem

In a `final class` data source that conforms to a `Sendable` protocol, you cannot just hold a single `ModelContext` and use it for both reads and writes in async methods. Swift 6 region-based isolation flags inserting a task-isolated `@Model` into a shared/inout `ModelContext` as a region violation.

Concretely, this fails to compile (or is rejected by strict concurrency):

```swift
final class SlideshowDataSource: SlideshowDataSourceProtocol {
    private let sharedContext: Mutex<ModelContext>
    // ...
    func save(_ model: SlideshowModel) async throws {
        try sharedContext.withLock { ctx in
            ctx.insert(model)   // ❌ region isolation violation:
            try ctx.save()      //    `model` is task-isolated; `ctx` would
                                //    receive a value whose region differs.
        }
    }
}
```

`Mutex.withLock` takes the wrapped value as `inout sending`, and `model` arrives task-isolated — the regions can't be merged.

## Workaround

Split read and write paths:

- **Reads** use a shared `Mutex<ModelContext>` so `fetchAll`, `fetch(id:)`, `delete(id:)` all reuse one context — avoiding REPEATED_CONTEXT.
- **Writes** create a fresh scoped `ModelContext(container)` per call, insert, and `save()`. The change lands in the persistent store and is visible to the shared context on its next fetch (SwiftData's coordinator-style behavior).

```swift
func save(_ model: SlideshowModel) async throws {
    let context = ModelContext(container)   // scoped, freshly task-isolated
    context.insert(model)
    try context.save()
}
```

`delete(id:)` does NOT need this workaround because it operates by predicate (`UUID`, a Sendable value), not by inserting a model:

```swift
func delete(id: UUID) async throws {
    try sharedContext.withLock { ctx in
        try ctx.delete(model: SlideshowModel.self, where: #Predicate { $0.id == id })
        try ctx.save()
    }
}
```

## Why it matters

- A naive `Mutex<ModelContext>` design hits a non-obvious Swift 6 error that doesn't surface until you try to use it.
- The pure "one fresh context per method" alternative trips REPEATED_CONTEXT in arch review.
- The mixed approach (shared context for reads, scoped context for inserts) threads both needles, but only because SwiftData propagates committed writes between contexts via the persistent store.

## Where this came up

`Sources/Infrastructure/SwiftData/SlideshowDataSource.swift` — implementing `SlideshowDataSourceProtocol` for the slideshow-playback feature. Same pattern likely applies to any future `*DataSource` that takes an `@Model` instance as a save argument (as opposed to a Sendable id/predicate).
