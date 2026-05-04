# SwiftData @Model instances work outside ModelContext for unit testing

In `SlideshowRepositoryTests` and `ImageRepositoryTests`, we created and configured `SlideshowModel` and `SlideModel` instances without inserting them into a `ModelContext`. This works reliably for mock data:

```swift
let model = SlideshowModel(id: UUID(), name: "Test")
model.slides = [
    SlideModel(id: UUID(), localIdentifier: "slide-1", order: 0, duration: 3.0)
]
mockDataSource.fetchAllResult = [model]
```

**Why it works**: SwiftData's `@Model` macro generates backing storage (`_$backingData`) that works in-memory without a context. Properties and relationships store values in the ephemeral backing data. Persistence (saving to/loading from the underlying store) requires a context, but in-memory use does not.

**Relationship handling**: Setting `model.slides = [slideModel]` on an uninserted model works because the relationship array is stored in-memory. Inverse relationships (`slideModel.slideshow`) are enforced at persistence time, not in-memory time, so accessing or setting the inverse outside a context does not crash.

**Pattern**: For repository unit tests with mocks, create `@Model` instances freely without a context. The models behave like regular in-memory objects. Use real `ModelContext` only for integration tests that need persistence semantics.

**Why it matters**: Allows lightweight, fast unit tests that mock data sources without the overhead of setting up SwiftData containers or persistence. The test fixtures are indistinguishable from production models.

See: `Tests/RepositoriesTests/SlideshowRepositoryTests.swift:360-374` (slides in `fetchAll()` mock)
