# SwiftData Practical Guide — Common Pitfalls in Data Persistence

**Category:** Advanced (Cross-Topic Guide)

SwiftData is Apple's data persistence framework that automatically saves Swift classes annotated with the `@Model` macro to a database. However, as a framework that has only recently emerged as the successor to Core Data, it has many **implicit behaviors**, and there are cases where data silently disappears without any errors.

This guide compiles the pitfalls actually encountered during 10slide development, along with safe patterns to follow.

---

## Overview

| Pitfall | Symptom | Severity |
|---------|---------|----------|
| Parent-child relationship insertion order | Child records silently disappear | High |
| Orphan records from relationship reassignment | Old child records persist in the DB | Medium |
| Property rename migration | App crashes on launch | High |
| `ModelContext` thread safety | Data corruption / crashes | High |
| `@Model` crossing actor boundaries | Compile error | Medium |

> **Architecture note**: In 10slide, a single generic `SwiftDataStore` actor (Infrastructure) handles all SwiftData I/O, while `@Model` types and `FetchDescriptor` construction live in the Repositories layer.

---

## 1. @Model Parent-Child Relationships — The Insertion Order Trap

### Problem

If you assign child models to a parent model's `@Relationship` property before calling `modelContext.insert()`, the **child models are silently lost**. `save()` succeeds without throwing an error, but the next `fetch()` returns an empty array for the children.

In 10slide, this manifested as a bug where "images loaded from the library were not displayed in the slideshow."

### Incorrect example

```swift
// ❌ Assigning children before insert — children are not saved
let model = SlideshowModel(id: id, name: name, ...)
model.slides = slides.map { SlideModel(id: $0.id, ...) }  // Children are outside the context
modelContext.insert(model)
try modelContext.save()
// → fetchAll() returns model.slides == []  (children are gone!)
```

### Correct example

```swift
// ✅ Insert parent → insert children → assign relationship
let model = SlideshowModel(id: id, name: name, ...)
modelContext.insert(model)  // ① Register parent in context first

let slideModels = slides.map { SlideModel(id: $0.id, ...) }
slideModels.forEach { modelContext.insert($0) }  // ② Register children in context too

model.slides = slideModels  // ③ Assign while both are in the context
try modelContext.save()
```

### Rules

- **Set up relationships only after inserting both parent and children**
- Even if `save()` returns without error, it does not guarantee that relationships were saved
- In tests, verify all the way through `save()` → `fetch()` → checking the child count

---

## 2. Orphan Records That Persist After Relationship Reassignment

### Problem

When you overwrite a `@Relationship` array with a new array, old child objects **remain in the database**. `deleteRule: .cascade` only triggers **when the parent is deleted**, not when the relationship array is reassigned.

### Incorrect example

```swift
// ❌ Old children remain in the DB (orphan records)
func update(_ slideshow: Slideshow, context: ModelContext) throws {
    let id = slideshow.id
    let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
    let existing = try context.fetch(descriptor).first!
    existing.slides = slideshow.slides.map { SlideModel(...) }  // Old SlideModels are not deleted
    try context.save()
}
```

Each repeated save accumulates old `SlideModel` instances, bloating the database.

### Correct example

```swift
// ✅ Explicitly delete old children before setting new ones
// (actual pattern from SlideshowRepository.save)
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id
    let slides = slideshow.slides

    try await store.write { context in
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })

        if let existing = try context.fetch(descriptor).first {
            // ① Delete all old children
            existing.slides.forEach { context.delete($0) }

            // ② Insert new children
            let newSlides = slides.map { SlideModel(id: $0.id, ...) }
            newSlides.forEach { context.insert($0) }

            // ③ Reassign the relationship
            existing.slides = newSlides
        } else {
            // New creation path
            let model = SlideshowModel(...)
            context.insert(model)
            // ...(set up children in the correct order from Pattern 1)
        }
        try context.save()
    }
}
```

### Rules

- Delete old children with `modelContext.delete()` before overwriting the relationship array
- `deleteRule: .cascade` does not trigger on relationship reassignment — **only on parent deletion**
- Always follow this procedure in upsert (update if exists, create if not) patterns

---

## 3. Property Renaming and Migration Pitfalls

### Problem

Renaming a property on a `@Model` causes SwiftData's automatic migration (Lightweight Migration) to **fail**. The app crashes on launch.

```
Fatal error: DI initialization failed: SwiftDataError(_error: loadIssueModelContainer)
Validation error missing attribute values on mandatory destination attribute
```

SwiftData interprets a rename as "deletion of the old column + addition of a new column." Since existing rows have no value for the new column, non-optional properties will always cause an error.

### Safe changes vs dangerous changes

| Change | Automatic migration | Result |
|--------|-------------------|--------|
| Adding a new property (with default value) | Succeeds | Existing rows get the default value |
| Removing a property | Succeeds | Column is ignored |
| Renaming a property | **Fails** | Crash |
| Changing a type (e.g., String → Int) | **Fails** | Crash |
| Optional → Non-optional | **Fails** | Crashes if existing rows contain nil |

### Incorrect example

```swift
// ❌ Simply renaming a property — automatic migration fails
@Model
final class SlideshowModel {
    // var title: String  ← old name
    var name: String      // ← new name (SwiftData interprets as "delete title + add name")
}
```

### Correct example (recovery during development)

```bash
# ✅ During development, delete the persistent store and recreate it
# The actual path includes the app's bundle ID subdirectory, e.g.:
rm -rf ~/Library/Application\ Support/com.example.TenSlide/default.store
# Check your actual path in Console.app or by searching ~/Library/Application\ Support/
```

### Correct example (after production release)

```swift
// ✅ Define migration using VersionedSchema
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] = [SlideshowModelV1.self]

    @Model final class SlideshowModelV1 {
        var title: String  // old name
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    static var models: [any PersistentModel.Type] = [SlideshowModel.self]
}

// Define the conversion from the old column to the new column using MigrationStage
```

### Rules

- During development, property renames can be handled by deleting the persistent store
- After a production release, `VersionedSchema` + `MigrationStage` is required
- Adding new properties (with default values) is safe

---

## 4. The @ModelActor Pattern — Thread-Safe Data Access

### Problem

`ModelContext` is not thread-safe. Even if you serialize access with `Mutex<ModelContext>`, the **execution thread may differ each time**. If a `@Relationship`'s lazy loading triggers on a different thread, data corruption or crashes can occur.

### Incorrect example

```swift
// ❌ Mutex serializes access but does not pin to a thread
final class UnsafeStore: Sendable {
    private let context: Mutex<ModelContext>

    func fetchAll() throws -> [SlideshowModel] {
        context.withLock { ctx in
            try ctx.fetch(FetchDescriptor<SlideshowModel>())
            // ⚠️ Accessing model.slides triggers lazy loading
            // ⚠️ Crashes if this thread differs from the context's home thread
        }
    }
}
```

### Correct example — Generic `SwiftDataStore`

In 10slide, a single **generic** `@ModelActor` actor called `SwiftDataStore` handles all SwiftData access. It exposes three operations (`fetch`, `delete`, `write`) that accept generic type parameters, so there is no need to create per-entity data sources.

```swift
// Sources/Infrastructure/SwiftData/SwiftDataStore.swift
@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol {
    func fetch<T: PersistentModel, R: Sendable>(
        _ descriptor: FetchDescriptor<T>,
        transform: @Sendable (T) throws -> R
    ) throws -> [R] {
        try modelContext.fetch(descriptor).map(transform)
    }

    func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws {
        try modelContext.delete(model: type, where: predicate)
        try modelContext.save()
    }

    func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
        try work(modelContext)
    }
}
```

The `transform` closure in `fetch` runs **inside the actor**, so `@Relationship` traversal is safe. The caller (a Repository) provides the `FetchDescriptor` and the conversion logic.

### Rules

- Use `@ModelActor actor` for all SwiftData access — never `Mutex<ModelContext>`
- `init(modelContainer:)` is generated by the macro — do not write it yourself
- One generic store serves the entire app — no per-entity data source actors needed

---

## 5. The Transform Pattern — Converting @Model Inside the Actor Boundary

### Problem

`@Model` classes are not `Sendable`, so returning them directly from a `@ModelActor` causes a compile error. Even if compilation were to succeed, accessing `@Relationship` properties outside the actor's thread would cause crashes.

### Incorrect example

```swift
// ❌ Returning @Model from the actor — compile error
func fetchAll() throws -> [SlideshowModel] {  // SlideshowModel is non-Sendable
    try modelContext.fetch(FetchDescriptor<SlideshowModel>())
}
```

```swift
// ❌ Forcing it through with @unchecked Sendable — crash risk
extension SlideshowModel: @unchecked Sendable { }
```

### Correct example — Repository calls `fetch` with a transform closure

In 10slide, `@Model` types live in `Repositories/Models/` (not Infrastructure). Repositories supply a transform closure to `SwiftDataStore.fetch()` that converts `@Model` → domain entity **inside the actor boundary**:

```swift
// Sources/Repositories/Implementations/SlideshowRepository.swift
final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    func fetchAll() async throws -> [Slideshow] {
        try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in
            slideshow(from: $0)  // @Model → Entity inside the actor
        }
    }

    private func slideshow(from model: SlideshowModel) -> Slideshow {
        let config = SlideshowConfig(
            duration: SlideDuration(rawValue: model.durationRawValue) ?? .five,
            transition: TransitionType(rawValue: model.transitionRawValue) ?? .default,
            loop: model.loop
        )
        let slides = model.slides
            .sorted { $0.order < $1.order }
            .map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, order: $0.order, duration: $0.duration, title: $0.title) }
        return Slideshow(id: model.id, name: model.name, slides: slides, config: config, createdAt: model.createdAt)
    }
}
```

For mutations, use `store.write(_:)` to perform multi-step operations atomically inside the actor:

```swift
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id
    try await store.write { context in
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.slides.forEach { context.delete($0) }   // Delete old children
            // ... insert new children, assign relationship
        } else {
            // ... create new parent and children
        }
        try context.save()
    }
}
```

### Directory structure (actual)

```
Infrastructure/SwiftData/
└── SwiftDataStore.swift         # Generic @ModelActor — the only SwiftData actor

Repositories/
├── Models/
│   ├── SlideshowModel.swift     # @Model class
│   └── SlideModel.swift         # @Model class
├── Implementations/
│   └── SlideshowRepository.swift  # Builds FetchDescriptor, supplies transform closure
└── Protocols/
    └── SlideshowRepositoryProtocol.swift
```

### Rules

- `@Model` types live in `Repositories/Models/`, not Infrastructure
- Convert `@Model` → domain entity via the `transform` closure passed to `store.fetch()`
- Multi-step mutations use `store.write(_:)` to run atomically inside the actor
- `@Model` must never appear in protocol signatures — only domain entities cross the boundary

---

## Summary

| Pitfall | Cause | Solution |
|---------|-------|----------|
| Child records disappear | Assigning relationship before insert | Follow the order: insert parent → insert children → assign relationship |
| Orphan records persist | Misunderstanding of `deleteRule: .cascade` | Delete old children with `modelContext.delete()` before reassignment |
| Crash on property rename | Limitations of Lightweight Migration | Use `VersionedSchema` + `MigrationStage` |
| `ModelContext` thread violation | `Mutex` does not pin to a thread | Use generic `@ModelActor actor` (`SwiftDataStore`) |
| `@Model` compile error | Non-Sendable crossing actor boundary | Convert to domain entity via `transform` closure inside the actor |

### Principles

1. **Beware of SwiftData's silent failures** — even if `save()` succeeds, data may not actually be persisted
2. **Confine `@Model` inside the actor** — convert to domain entities via the `transform` closure in `store.fetch()`, or mutate inside `store.write()`
3. **Respect insertion order** — follow the three-step sequence: parent → children → relationship assignment
