# SwiftData @ModelActor + DTO Architecture

## Overview

When a `@ModelActor` actor needs to return SwiftData models to callers (which live on a different actor), the `@Model` classes cannot cross the actor boundary because they are non-Sendable. The solution is a DTO (Data Transfer Object) struct layer.

## Directory Layout

```
Infrastructure/SwiftData/
├── DTO/
│   ├── SlideModel.swift       # @Model class — stays inside actor only
│   ├── SlideshowModel.swift   # @Model class — stays inside actor only
│   ├── SlideDTO.swift         # Sendable struct — safe to cross boundaries
│   └── SlideshowDTO.swift     # Sendable struct — safe to cross boundaries
├── SlideDataSource.swift      # @ModelActor actor
└── SlideshowDataSource.swift  # @ModelActor actor
```

## Conversion Responsibility

All `@Model` ↔ DTO conversion lives INSIDE the actor. Callers only see DTOs.

```swift
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {

    // Returns DTO — safe to send across actor boundary
    func fetch(id: UUID) throws -> SlideshowDTO? {
        let descriptor = FetchDescriptor<SlideshowModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(dto(from:))
    }

    // Accepts DTO — creates @Model inside actor
    func save(_ dto: SlideshowDTO) throws {
        let model = SlideshowModel(id: dto.id, name: dto.name, ...)
        model.slides = dto.slides.map { SlideModel(id: $0.id, ...) }
        modelContext.insert(model)
        try modelContext.save()
    }

    // Relationship traversal (model.slides) happens inside actor — safe
    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        SlideshowDTO(
            id: model.id,
            slides: model.slides.map { SlideDTO(id: $0.id, ...) }
        )
    }
}
```

## Relationship Traversal Safety

`@Relationship` properties (e.g., `SlideshowModel.slides`) are lazy-loaded. Accessing them outside the ModelContext's home executor triggers Core Data faults on the wrong thread — silent corruption or crash. Accessing inside the `@ModelActor` executor is safe because the actor's executor IS the ModelContext's home.

## DI Container Wiring

```swift
// InfrastructureContainer.swift
slideshowDataSource = SlideshowDataSource(modelContainer: modelContainer)
//                                                        ^^^^^^^^^^^^^^
// @ModelActor synthesizes init(modelContainer:) — no init to write
```

## Testing

Integration tests use an in-memory `ModelContainer`:

```swift
let schema = Schema([SlideshowModel.self, SlideModel.self])
let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
container = try ModelContainer(for: schema, configurations: [config])
sut = SlideshowDataSource(modelContainer: container)
```

Unit tests of repositories mock at the protocol level with `SlideshowDTO` fixtures — no SwiftData dependency needed:

```swift
final class MockSlideshowDataSource: SlideshowDataSourceProtocol, @unchecked Sendable {
    var fetchAllResult: [SlideshowDTO] = []
    func fetchAll() async throws -> [SlideshowDTO] { fetchAllResult }
    ...
}
```

## References

- `Sources/Infrastructure/SwiftData/SlideshowDataSource.swift`
- `Sources/Infrastructure/SwiftData/DTO/SlideshowDTO.swift`, `SlideDTO.swift`
- `Tests/InfrastructureTests/SlideshowDataSourceTests.swift`
- `Tests/RepositoriesTests/SlideshowRepositoryTests.swift`
