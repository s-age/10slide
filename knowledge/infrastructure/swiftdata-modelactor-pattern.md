---
type: discovery
context: when writing a SwiftData data source under Swift 6 strict concurrency
keywords: [SwiftData, @ModelActor, Swift6, concurrency, Mutex, Sendable, ModelContext, DTO]
---

## What

`Mutex<ModelContext>` serializes calls but does NOT guarantee the same thread. `ModelContext`
relationship faults (lazy-loaded `@Relationship` properties) are triggered on whatever thread
touches the model — if that thread differs from the context's home thread it silently corrupts
data or crashes. `@Model` classes are also non-Sendable, so returning them across actor boundaries
triggers Swift 6 compiler errors.

`@ModelActor` binds all model access to one actor executor (the same thread as the container).
Convert `@Model` → Sendable DTO **inside** the actor before returning. Supersedes the
`Mutex<ModelContext>` split-read/write pattern in `swiftdata-modelcontext-region-isolation.md`.

## Do

Declare data sources as `@ModelActor actor`, not `final class`:

```swift
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    // modelContext and modelExecutor are synthesized
    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))   // convert to Sendable struct INSIDE actor
    }

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        SlideshowDTO(id: model.id, name: model.name, slides: model.slides.map { ... })
    }
}
```

Key rules:
- `init(modelContainer:)` is synthesized — do **not** write your own.
- Protocol declares `async throws`; Swift wraps the synchronous actor methods automatically.
- All `@Relationship` traversal must happen inside the actor executor.

## Don't

- Don't use `Mutex<ModelContext>` — it doesn't pin the context to a single thread.
- Don't add `@unchecked Sendable` to `@Model` classes to silence compiler errors — it's unsafe.
- Don't return `@Model` instances from `@ModelActor` methods — return DTOs only.
