---
type: discovery
context: when writing tests for @ModelActor SwiftData data sources and their repositories
keywords: [SwiftData, @ModelActor, testing, in-memory, ModelContainer, DTO, mock, integration test]
---

## What

`@ModelActor` data sources require a real `ModelContainer` for integration tests. Use an
in-memory configuration so tests don't touch disk. Repository unit tests mock at the DTO
protocol level — no SwiftData dependency needed at all.

See `Tests/InfrastructureTests/SlideshowDataSourceTests.swift` and
`Tests/RepositoriesTests/SlideshowRepositoryTests.swift`.

## Do

**Integration tests** — in-memory `ModelContainer`:
```swift
let schema = Schema([SlideshowModel.self, SlideModel.self])
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
container = try ModelContainer(for: schema, configurations: [config])
sut = SlideshowDataSource(modelContainer: container)
```

**Unit tests** — mock the protocol with DTO fixtures, no SwiftData needed:
```swift
final class MockSlideshowDataSource: SlideshowDataSourceProtocol, @unchecked Sendable {
    var fetchAllResult: [SlideshowDTO] = []
    func fetchAll() async throws -> [SlideshowDTO] { fetchAllResult }
}
```

## Don't

- Don't use a persistent `ModelContainer` in unit tests — it leaves state across test runs.
- Don't mock `@Model` classes directly — mock the DTO protocol instead.
- Don't share a single `ModelContainer` across test methods without resetting state between runs.
