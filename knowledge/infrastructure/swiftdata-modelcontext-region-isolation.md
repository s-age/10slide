---
type: problem
context: when using SwiftData ModelContext in a Sendable class under Swift 6 strict concurrency
keywords: [SwiftData, ModelContext, Swift6, region-isolation, Mutex, Sendable, insert]
---

## What

Swift 6 region-based isolation prevents inserting a task-isolated `@Model` instance into a shared
`Mutex<ModelContext>` via `withLock`. The `@Model` object arrives task-isolated; `Mutex.withLock`
takes the wrapped value as `inout sending`, and the regions cannot be merged — the compiler rejects
it. A pure "one fresh context per method" workaround triggers `REPEATED_CONTEXT` in architecture
review.

The working pattern splits the paths:

- **Reads / predicate-based deletes** (Sendable values like `UUID`) use a shared `Mutex<ModelContext>`.
- **Writes (insert)** create a scoped `ModelContext(container)` per call; SwiftData propagates the
  committed write to the shared context on its next fetch via the persistent store coordinator.

```swift
// Reads — reuse shared context
func fetchAll() async throws -> [SlideshowModel] {
    sharedContext.withLock { try $0.fetch(FetchDescriptor<SlideshowModel>()) }
}

// Writes — fresh scoped context per call
func save(_ model: SlideshowModel) async throws {
    let context = ModelContext(container)
    context.insert(model)
    try context.save()
}
```

First appeared in `Sources/Infrastructure/SwiftData/SlideshowDataSource.swift`. Same pattern
applies to any future `*DataSource` that accepts an `@Model` instance as a save argument.

## Do

- Use a shared `Mutex<ModelContext>` for fetches and predicate-based deletes.
- Create a fresh `ModelContext(container)` scoped to each call that inserts a task-isolated `@Model`.

## Don't

- Don't call `ctx.insert(model)` inside `sharedContext.withLock { }` — Swift 6 rejects the region
  merge at compile time.
- Don't create a fresh `ModelContext` for every read operation — that triggers `REPEATED_CONTEXT`.
- Don't mark the data source `@unchecked Sendable` to silence the region error — it hides the race.
