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

---

## 1. @Model Parent-Child Relationships — The Insertion Order Trap

### Problem

If you assign child models to a parent model's `@Relationship` property before calling `modelContext.insert()`, the **child models are silently lost**. `save()` succeeds without throwing an error, but the next `fetch()` returns an empty array for the children.

In 10slide, this manifested as a bug where "images loaded from the library were not displayed in the slideshow."

### Incorrect example

```swift
// ❌ Assigning children before insert — children are not saved
let model = SlideshowModel(id: dto.id, name: dto.name)
model.slides = dto.slides.map { SlideModel(id: $0.id, ...) }  // Children are outside the context
modelContext.insert(model)
try modelContext.save()
// → fetchAll() returns model.slides == []  (children are gone!)
```

### Correct example

```swift
// ✅ Insert parent → insert children → assign relationship
let model = SlideshowModel(id: dto.id, name: dto.name)
modelContext.insert(model)  // ① Register parent in context first

let slideModels = dto.slides.map { SlideModel(id: $0.id, ...) }
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
func update(_ dto: SlideshowDTO) throws {
    let existing = try fetchExisting(id: dto.id)
    existing.slides = dto.slides.map { SlideModel(...) }  // Old SlideModels are not deleted
    try modelContext.save()
}
```

Each repeated save accumulates old `SlideModel` instances, bloating the database.

### Correct example

```swift
// ✅ Explicitly delete old children before setting new ones
func save(_ dto: SlideshowDTO) throws {
    let id = dto.id
    let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })

    if let existing = try modelContext.fetch(descriptor).first {
        // ① Delete all old children
        existing.slides.forEach { modelContext.delete($0) }

        // ② Insert new children
        let newSlides = dto.slides.map { SlideModel(id: $0.id, ...) }
        newSlides.forEach { modelContext.insert($0) }

        // ③ Reassign the relationship
        existing.slides = newSlides
    } else {
        // New creation path
        let model = SlideshowModel(...)
        modelContext.insert(model)
        // ...(set up children in the correct order from Pattern 1)
    }
    try modelContext.save()
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
rm ~/Library/Application\ Support/default.store
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
final class SlideshowDataSource: Sendable {
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

### Correct example

```swift
// ✅ @ModelActor pins all access to the same thread
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    // modelContext is auto-generated by the macro

    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))
    }

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        // @Relationship lazy loading is safely performed on this actor's thread
        SlideshowDTO(
            id: model.id,
            name: model.name,
            slides: model.slides.map { slide in
                SlideDTO(id: slide.id, localIdentifier: slide.localIdentifier, ...)
            }
        )
    }
}
```

### Rules

- Declare SwiftData data sources with `@ModelActor actor`
- `init(modelContainer:)` is generated by the macro — do not write it yourself
- DI container initialization: `SlideshowDataSource(modelContainer: modelContainer)`

---

## 5. The DTO Pattern — Never Let @Model Escape the Actor Boundary

### Problem

`@Model` classes are not `Sendable`, so returning them directly from a `@ModelActor` causes a compile error. Even if compilation were to succeed, accessing `@Relationship` properties outside the actor's thread would cause crashes.

### Incorrect example

```swift
// ❌ Returning @Model from the actor — compile error
@ModelActor
actor SlideshowDataSource {
    func fetchAll() throws -> [SlideshowModel] {  // SlideshowModel is non-Sendable
        try modelContext.fetch(FetchDescriptor<SlideshowModel>())
    }
}
```

```swift
// ❌ Forcing it through with @unchecked Sendable — crash risk
extension SlideshowModel: @unchecked Sendable { }
```

### Correct example

```swift
// ✅ Define Sendable DTO structs
struct SlideshowDTO: Sendable {
    let id: UUID
    let name: String
    let slides: [SlideDTO]
}

struct SlideDTO: Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
    let duration: Double
}
```

```swift
// ✅ Convert @Model → DTO inside the actor before returning
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))  // Convert inside the actor
    }

    func save(_ dto: SlideshowDTO) throws {
        // DTO → @Model conversion is also done inside the actor
        let model = SlideshowModel(id: dto.id, name: dto.name)
        modelContext.insert(model)
        let slideModels = dto.slides.map { SlideModel(id: $0.id, ...) }
        slideModels.forEach { modelContext.insert($0) }
        model.slides = slideModels
        try modelContext.save()
    }
}
```

### Directory structure

```
Infrastructure/SwiftData/
├── DTO/
│   ├── SlideDTO.swift          # Sendable struct
│   └── SlideshowDTO.swift      # Sendable struct
├── SlideshowDataSource.swift   # @ModelActor actor (keeps @Model confined internally)
└── SlideDataSource.swift       # @ModelActor actor
```

### Rules

- `@Model` must never appear in protocol signatures — only expose DTOs
- DTOs are placed in `Infrastructure/SwiftData/DTO/`
- Conversion logic (`dto(from:)` / `model(from:)`) is written inside the `@ModelActor`
- `@Relationship` traversal (accessing `model.slides`) must always be completed inside the actor

---

## Summary

| Pitfall | Cause | Solution |
|---------|-------|----------|
| Child records disappear | Assigning relationship before insert | Follow the order: insert parent → insert children → assign relationship |
| Orphan records persist | Misunderstanding of `deleteRule: .cascade` | Delete old children with `modelContext.delete()` before reassignment |
| Crash on property rename | Limitations of Lightweight Migration | Use `VersionedSchema` + `MigrationStage` |
| `ModelContext` thread violation | `Mutex` does not pin to a thread | Use `@ModelActor actor` |
| `@Model` compile error | Non-Sendable crossing actor boundary | Convert to DTO before returning |

### Principles

1. **Beware of SwiftData's silent failures** — even if `save()` succeeds, data may not actually be persisted
2. **Confine `@Model` inside the actor** — only expose `Sendable` DTOs to the outside
3. **Respect insertion order** — follow the three-step sequence: parent → children → relationship assignment
