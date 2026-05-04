---
type: gotcha
context: Replacing a SwiftData @Relationship array with a new set of child objects
keywords: [SwiftData, Relationship, orphan, cascade, delete, upsert, deleteRule, reassignment]
---

## What

Reassigning a `@Relationship` array property does **not** delete the old child objects. `deleteRule: .cascade` only fires when the *parent* model itself is deleted — it does not apply when the relationship array is overwritten.

```swift
// BAD — old SlideModel rows remain in the database
model.slides = newSlides
```

## Do

Fetch the existing record, explicitly delete each old child via `modelContext.delete()`, insert the new children, then reassign the relationship array.

```swift
func save(_ dto: SlideshowDTO) throws {
    let id = dto.id
    let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
    if let existing = try modelContext.fetch(descriptor).first {
        existing.slides.forEach { modelContext.delete($0) }
        let newSlides = makeSlideModels(from: dto.slides)
        newSlides.forEach { modelContext.insert($0) }
        existing.slides = newSlides
        // update remaining fields…
    } else {
        // fresh insert
    }
    try modelContext.save()
}
```

This upsert pattern is the safe approach for any SwiftData model with child relationships.

## Don't

- Don't assume `deleteRule: .cascade` cleans up orphans on array reassignment — it only fires on parent deletion.
- Don't insert new children and save repeatedly in a loop when `@Attribute(.unique)` is present; batch the inserts before a single `save()`.
