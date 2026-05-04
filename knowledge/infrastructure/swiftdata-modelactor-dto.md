---
type: decision
context: when designing the DTO layer for a @ModelActor SwiftData data source
keywords: [SwiftData, @ModelActor, DTO, Sendable, @Relationship, directory layout, conversion]
---

## What

`@Model` classes cannot cross actor boundaries (non-Sendable). All data sources expose Sendable
DTO structs; `@Model` objects never leave the `@ModelActor` executor. Conversion between model
and DTO is the data source's sole responsibility.

Directory layout:
```
Infrastructure/SwiftData/
├── DTO/
│   ├── SlideDTO.swift         # Sendable struct — safe to cross boundaries
│   └── SlideshowDTO.swift     # Sendable struct — safe to cross boundaries
├── SlideDataSource.swift      # @ModelActor actor (keeps @Model inside)
└── SlideshowDataSource.swift  # @ModelActor actor (keeps @Model inside)
```

## Do

Define plain `Sendable` structs in `Infrastructure/SwiftData/DTO/`:

```swift
struct SlideshowDTO: Sendable {
    let id: UUID; let name: String; let slides: [SlideDTO]
}
```

Convert inside the actor in both directions:

```swift
// Out: @Model → DTO
func fetch(id: UUID) throws -> SlideshowDTO? {
    try modelContext.fetch(FetchDescriptor<SlideshowModel>(...)).first.map(dto(from:))
}

// In: DTO → @Model (create and insert inside actor)
func save(_ dto: SlideshowDTO) throws {
    let model = SlideshowModel(id: dto.id, name: dto.name)
    model.slides = dto.slides.map { SlideModel(id: $0.id, ...) }
    modelContext.insert(model); try modelContext.save()
}
```

Wire in `InfrastructureContainer` using the synthesized initializer:
```swift
slideshowDataSource = SlideshowDataSource(modelContainer: modelContainer)
```

## Don't

- Don't access `@Relationship` properties (e.g. `model.slides`) outside the actor executor.
- Don't expose `@Model` types in protocol signatures — use DTOs only.
- Don't write a custom `init` on a `@ModelActor` actor — the synthesized one is required.
