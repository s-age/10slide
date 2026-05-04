---
type: discovery
context: when creating SwiftData @Model fixtures for repository unit tests
keywords: [SwiftData, @Model, ModelContext, unit test, mock, fixture]
---

## What

`@Model` instances can be created and configured without inserting them into a `ModelContext`.
SwiftData's `@Model` macro generates backing storage (`_$backingData`) that works in-memory without
a context. Persistence requires a context, but in-memory property access and relationship
assignment do not.

Relationship arrays (e.g., `model.slides = [slideModel]`) work in-memory; inverse relationships
are enforced at persistence time, not in-memory time, so accessing them outside a context is safe.

See `Tests/RepositoriesTests/SlideshowRepositoryTests.swift:360-374` for a concrete example.

## Do

- Create `@Model` instances freely in unit test `setUp()` without a `ModelContext`.
- Assign relationship arrays directly: `model.slides = [SlideModel(...)]`.
- Use real `ModelContext` only for integration tests that need persistence semantics.

```swift
let model = SlideshowModel(id: UUID(), name: "Test")
model.slides = [
    SlideModel(id: UUID(), localIdentifier: "slide-1", order: 0, duration: 3.0)
]
mockDataSource.fetchAllResult = [model]
```

## Don't

- Don't spin up a `ModelContainer` just to create mock fixtures — it adds unnecessary overhead.
- Don't assume relationship inverses are populated outside a context; test only the side you set.
