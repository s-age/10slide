# Swift 6 Region Isolation and ModelContext

## Problem

Under Swift 6 strict region-based isolation, inserting a task-isolated `@Model` into an `inout sending ModelContext` violates the type system. This affects SwiftData operations in async code.

## Pattern

Split ModelContext usage:
- **Reads and deletes**: Use a shared `Mutex<ModelContext>` initialized once in `init()`. The row cache is reused, improving performance.
- **Inserts/saves**: Create a new `ModelContext` per operation, since insertion of a task-isolated model into `inout sending context` cannot cross the region boundary.

## Example

```swift
final class SlideshowDataSource: SlideshowDataSourceProtocol {
    private let sharedContext: Mutex<ModelContext>

    init(container: ModelContainer) {
        sharedContext = Mutex(ModelContext(container))
    }

    // fetchAll, fetch, delete use sharedContext.withLock { ... }
    // save uses a scoped context: let context = ModelContext(container); context.insert(model); try context.save()
}
```

## Why It Matters

Naive implementations create a fresh ModelContext for every operation, discarding the row cache. Shared context improves performance for reads, but save() must remain scoped due to Swift 6 semantics.

## References

- `Sources/Infrastructure/SwiftData/SlideshowDataSource.swift` (lines 29–36, save() method comment)
