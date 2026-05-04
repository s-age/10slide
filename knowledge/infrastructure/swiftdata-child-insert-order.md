---
type: gotcha
context: when inserting a parent @Model with @Relationship children inside a @ModelActor
keywords: [SwiftData, ModelActor, Relationship, insert, persistence, silent-data-loss]
---

## What

In a `@ModelActor`, assigning child `@Model` objects to a parent's `@Relationship` property
**before** inserting either into the context causes the children to be silently dropped on save.
`modelContext.save()` succeeds without error, but fetching the parent later returns an empty
relationship array. The parent record itself is visible; only its children are missing.

This caused library-loaded slideshows to show no images at playback time, while newly created
slideshows worked fine (they used the in-memory `Slideshow` entity and never hit the broken
fetch path). Fixed in `Sources/Infrastructure/SwiftData/SlideshowDataSource.swift` (commit 9283601).

## Do

Insert the parent first, then explicitly insert each child, then assign the relationship:

```swift
// CORRECT — children are in the context before the relationship is set
let model = SlideshowModel(...)
modelContext.insert(model)
let slideModels = dto.slides.map { SlideModel(...) }
slideModels.forEach { modelContext.insert($0) }
model.slides = slideModels
try modelContext.save()
```

## Don't

- Don't assign relationship properties before both parent and children are inserted into the
  context — SwiftData silently discards unregistered children on save.

```swift
// BROKEN — slides are never persisted
let model = SlideshowModel(...)
model.slides = dto.slides.map { SlideModel(...) }  // children not in context yet
modelContext.insert(model)
try modelContext.save()
// fetchAll() later returns SlideshowModel with model.slides == []
```

- Don't rely on `save()` returning without error as proof that relationships were persisted —
  this bug produces no thrown error.
