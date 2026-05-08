# Understanding SwiftDataStore

**Source file**: `Sources/Infrastructure/SwiftData/SwiftDataStore.swift`

## What Does This File Do?

`SwiftDataStore` is the "gateway" for saving, fetching, and deleting app data to and from disk.
It uses SwiftData, an Apple framework, and is designed to be safely callable from multiple threads.

```swift
import Foundation
import SwiftData

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

This is a simple file of only 22 lines, but it is packed with important Swift concepts. Let's read through them one by one.

---

## 1. `actor` -- A Thread-Safe "Guardian"

### Definition

`actor` is a keyword introduced in Swift 5.5. It is a reference type similar to `class`, but a special type that **automatically prevents multiple operations from modifying internal state simultaneously**.

### Why It Is Used Here

An app runs multiple operations in parallel (UI rendering, network communication, data saving, etc.). If two operations tried to modify the database at the same time, data could become corrupted. `actor` turns the gateway into "a turnstile that only one person can pass through at a time."

### What Would Happen Without It

```swift
// NG: With a plain class, concurrent access from multiple threads can break things
final class SwiftDataStore {
    var count = 0
    func increment() { count += 1 }  // If two threads call this at the same time, the count gets corrupted
}
```

With `class`, the developer must manually manage locks, which is error-prone. `actor` lets the compiler automatically guarantee mutual exclusion.

```swift
// OK: Just making it an actor lets the Swift compiler guarantee safety
actor SwiftDataStore { ... }
```

---

## 2. `@ModelActor` -- A SwiftData-Specific Macro

### Definition

`@ModelActor` is a **macro** (a mechanism for auto-generating code) provided by SwiftData. When applied to an `actor`, it auto-generates the initialization code (`init(modelContainer:)`) that SwiftData needs and the `modelContext` property that serves as the stage for data operations.

### Why It Is Used Here

SwiftData's `ModelContext` (discussed later) is tied to a thread. Using `@ModelActor` pins the `ModelContext` to that actor's thread, making it safe to use.

### What Would Happen Without It

```swift
// NG: Wrapping ModelContext in a Mutex does not make SwiftData thread-safe
final class SwiftDataStore {
    private let context: Mutex<ModelContext>  // This is the wrong approach
}
```

`ModelContext` has the constraint of "one per thread," so wrapping it in a `Mutex` does not solve the problem. Only when `@ModelActor` pins it to the actor's thread does it become safe.

```swift
// OK: @ModelActor automates the creation and pinning of modelContext
@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol { ... }
```

---

## 3. Generics `<T: PersistentModel, R: Sendable>` -- Making Types into "Variables"

### Definition

`<T: PersistentModel, R: Sendable>` is a **generics** declaration. `T` and `R` are "type variables" whose concrete types are determined by the caller.

- `T` is "some PersistentModel (a model type managed by SwiftData)"
- `R` is "some Sendable type (a type that can be safely passed between threads)"

### Why It Is Used Here

The `fetch` function is used for various models, such as "fetching slideshows" and "fetching slides." With generics, there is no need to rewrite the function for each type.

```swift
func fetch<T: PersistentModel, R: Sendable>(
    _ descriptor: FetchDescriptor<T>,
    transform: @Sendable (T) throws -> R
) throws -> [R]
```

### What Would Happen Without It

```swift
// NG: A separate function must be written for each type (code duplication)
func fetchSlides(_ descriptor: FetchDescriptor<SlideModel>) throws -> [Slide] { ... }
func fetchSlideshows(_ descriptor: FetchDescriptor<SlideshowModel>) throws -> [Slideshow] { ... }
// Functions keep multiplying as models are added...
```

With generics, a single `fetch` function handles all models.

---

## 4. `T.Type` -- Metatype Parameters

### Definition

`T.Type` is a **metatype** — a value that represents a type itself, not an instance of that type. It lets you pass a type as a function argument.

### How It Is Used in This File

```swift
func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws
```

The first parameter `type: T.Type` tells the function **which model type to delete**. The caller passes the type literal (e.g., `SlideshowModel.self`), and the compiler infers `T` from it.

```swift
// Caller (in SlideshowRepository):
try await store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
//                      ↑ T = SlideshowModel is inferred from this
```

> **Note**: `where` in this function signature is an **argument label**, not a generic `where` clause. It simply makes the call site read naturally: `delete(SlideshowModel.self, where: somePredicate)`.

---

## 5. `Predicate<T>` -- Type-Safe "Filter Conditions"

### Definition

`Predicate<T>` is a **filter condition that is type-checked at compile time**, provided by SwiftData (and the Swift standard library). It lets you write conditions like "only items where such-and-such field has such-and-such value" in Swift code.

### Why It Is Used Here

```swift
func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws
```

By using `Predicate<T>`, any condition expression that doesn't match the type causes a compile error. For example, you cannot pass a predicate for `SlideModel` to a deletion of `SlideshowModel`.

### What Would Happen Without It

```swift
// NG: The classic approach of writing queries as strings
func deleteWhere(sql: String) throws { ... }
// Caller: deleteWhere(sql: "slideName = 'vacation'")
// → Typos and type mismatches are not caught until runtime
```

With `Predicate<T>`, the compiler performs the check, so bugs can be caught before execution.

---

## 6. `@Sendable` Closures -- Closures Safe for Concurrent Processing

### Definition

`@Sendable` is an attribute indicating that a closure **can be safely passed between multiple threads**. Conforming to `Sendable` means "even if the value is copied and passed to any thread, it won't break."

### Why It Is Used Here

```swift
func fetch<T: PersistentModel, R: Sendable>(
    _ descriptor: FetchDescriptor<T>,
    transform: @Sendable (T) throws -> R   // ← @Sendable
) throws -> [R]
```

Because `fetch` is a method of an `actor`, it executes on a different thread (the actor's thread) from the caller. The `transform` closure also executes on that thread, so `@Sendable` is required. If a non-`@Sendable` closure attempts to unsafely capture external variables, a compile error occurs.

```swift
func write(_ work: @Sendable (ModelContext) throws -> Void) throws
```

The same applies to `write`. Since the `work` closure executes on the actor's thread, `@Sendable` is required.

### What Would Happen Without It

```swift
// NG: Without @Sendable, the compiler issues a warning or error
func fetch<T: PersistentModel, R: Sendable>(
    _ descriptor: FetchDescriptor<T>,
    transform: (T) throws -> R   // No @Sendable
) throws -> [R]
// → Error: a non-Sendable closure cannot be passed across actor boundaries
```

---

## 7. `ModelContext` -- SwiftData's "Workbench" for Data Operations

### Definition

`ModelContext` is the "workbench" for reading and writing data in SwiftData. All operations -- fetching, inserting, deleting, and saving data -- go through it.

### Why It Is Used Here

The `@ModelActor` macro auto-generates the `modelContext` property, so it can be used directly within `SwiftDataStore`'s methods.

```swift
func fetch<T: PersistentModel, R: Sendable>(...) throws -> [R] {
    try modelContext.fetch(descriptor).map(transform)  // ← Uses modelContext to fetch data
}

func delete<T: PersistentModel>(...) throws {
    try modelContext.delete(model: type, where: predicate)  // Delete
    try modelContext.save()  // Save (if forgotten, changes are not written to disk)
}

func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
    try work(modelContext)  // Pass ModelContext to the outside for flexible writing
}
```

The `modelContext.save()` after `delete` is important. SwiftData holds changes as "pending," and they are only committed to disk when `save()` is called.

### What Would Happen Without It

Without SwiftData, persisting data would require managing file reading/writing or SQL yourself, which is extremely complex. `ModelContext` is the abstraction layer that hides that complexity.

---

## 8. `throws` -- Propagating Errors to the Caller

### Definition

`throws` indicates that the function **may throw an error**. Calling a function marked with `throws` requires the `try` keyword.

### Why It Is Used Here

Database operations can fail (disk full, data corrupted, etc.). Using `throws` ensures that when an error occurs, it is reliably communicated to the caller.

```swift
func fetch<T: PersistentModel, R: Sendable>(...) throws -> [R] {
    try modelContext.fetch(descriptor).map(transform)
    // ↑ If fetch fails, an Error is thrown, and this function automatically throws too
}
```

### What Would Happen Without It

```swift
// NG: Ignoring the error and returning nil or an empty array prevents the caller from detecting failure
func fetch(...) -> [R]? {
    return try? modelContext.fetch(descriptor).map(transform)
    // On failure, nil is simply returned -- there's no way to know why it failed
}
```

The combination of `throws` + `try` forces errors to be handled **explicitly**.

---

## 9. Pitfalls Learned in Practice

Here are issues actually encountered during development with SwiftData and the Photos framework. All of them are "compiles fine but breaks at runtime" type bugs, so knowing about them in advance is important.

---

### Pitfall 1: SwiftData Parent-Child Insertion Order

#### What Happens

When you assign child models to a parent model's `@Relationship` property and then call `modelContext.insert()` inside a `@ModelActor`, **the child models are not saved to the database**. `modelContext.save()` succeeds without throwing an error, but when you later fetch the data, the relationship is empty.

In this project, this manifested as a bug where images from slideshows loaded from the library were not displayed at all. Since newly created slideshows worked correctly, the bug was slow to be discovered.

#### The Correct Way

```swift
// ✅ Insert parent → insert children → set relationship → save
let model = SlideshowModel(...)
modelContext.insert(model)                          // 1. Register the parent in the context first
let slideModels = dto.slides.map { SlideModel(...) }
slideModels.forEach { modelContext.insert($0) }     // 2. Register each child in the context individually
model.slides = slideModels                          // 3. Establish the relationship with both in the context
try modelContext.save()                             // 4. Save
```

#### The Wrong Way

```swift
// ❌ Setting the relationship before children are in the context -- children are lost
let model = SlideshowModel(...)
model.slides = dto.slides.map { SlideModel(...) }   // Children are not yet in the context!
modelContext.insert(model)                           // Only the parent is registered
try modelContext.save()
// → save() succeeds, but later fetching yields model.slides == []
```

**Key point**: Even if `save()` succeeds without error, that does not guarantee the relationships were saved correctly. Always follow the order: "insert parent -> insert children -> establish relationship."

---

### Pitfall 2: Orphan Records When Reassigning Relationships

#### What Happens

When you assign a new array of child objects to a `@Relationship` array property, **the old child objects remain in the database**. `deleteRule: .cascade` only triggers when the parent model itself is deleted; it does not work on array overwriting.

As updates are repeated, orphan records accumulate in the database, bloating storage.

#### The Correct Way

```swift
// ✅ Explicitly delete old children before inserting and associating new ones
// (actual pattern from SlideshowRepository.save)
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id
    let slides = slideshow.slides

    try await store.write { context in
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.slides.forEach { context.delete($0) }          // Delete old children
            let newSlides = slides.map { SlideModel(id: $0.id, ...) }
            newSlides.forEach { context.insert($0) }                // Insert new children
            existing.slides = newSlides                              // Establish relationship
        } else {
            // New creation path
        }
        try context.save()
    }
}
```

#### The Wrong Way

```swift
// ❌ Overwriting the array directly -- old child records remain as orphans
existing.slides = newSlides
try modelContext.save()
// → Old SlideModel records persist in the DB, and storage keeps growing
```

**Key point**: `deleteRule: .cascade` is only a feature that "takes children down with the parent when the parent is deleted." For "replacing children," the developer must explicitly `delete()` the old children.

---

### Pitfall 3: Do Not Use `.opportunistic` for PHImageManager's deliveryMode

> **Note**: This pitfall relates to `Sources/Infrastructure/Image/ImageDataSource.swift`, not `SwiftDataStore.swift`. It is included here because it is a common Infrastructure-layer gotcha involving SwiftData-adjacent patterns (continuation safety).

#### What Happens

When wrapping `PHImageManager` with Swift Concurrency's `withCheckedThrowingContinuation`, using `deliveryMode = .opportunistic` causes **the callback to be called twice** (first with a low-quality preview, then with the full image). Since `continuation.resume()` is executed twice, the Swift runtime triggers a crash.

On the other hand, if you skip the first callback with `if isDegraded { return }`, when the second callback fails, `resume()` is never called, and the task hangs permanently, causing a memory leak.

#### The Correct Way

```swift
// ✅ Using .highQualityFormat guarantees the callback is called exactly once
let options = PHImageRequestOptions()
options.deliveryMode = .highQualityFormat  // Guarantees the callback is called only once

let data: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(
        for: asset, options: options
    ) { data, _, _, _ in
        if let data {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: ImageDataSourceError.dataUnavailable)
        }
    }
}
```

#### The Wrong Way

```swift
// ❌ .opportunistic delivers the callback twice → continuation resumes twice and crashes
let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic

let data: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(
        for: asset, options: options
    ) { data, _, _, _ in
        if let data {
            continuation.resume(returning: data)  // Crashes on the second call!
        }
    }
}
```

**Key point**: `withCheckedThrowingContinuation` expects `resume()` to be called **exactly once**. When wrapping APIs whose callbacks are called multiple times, either choose an option that ensures a single callback, or use `AsyncStream`.

---

## Summary: What You Can Learn from This File

| Concept | One-Line Summary |
|------|-----------|
| `actor` | A "guardian" type that prevents simultaneous access from multiple threads |
| `@ModelActor` | A macro that auto-generates SwiftData initialization and `modelContext` |
| Generics `<T, R>` | A mechanism that makes types into "variables" to increase reusability |
| Type constraint `: PersistentModel` | Syntax for adding conditions to generic types |
| `Predicate<T>` | Filter conditions that are type-checked at compile time |
| `@Sendable` | A closure attribute that lets the compiler guarantee safe cross-thread passing |
| `ModelContext` | The "workbench" that handles all SwiftData reads and writes |
| `throws` | A mechanism for propagating function errors to the caller |

This file is only 22 lines long, but it is packed with the core concepts of modern Swift programming: "thread safety," "type generalization," and "error propagation." Once you understand these concepts, you will be able to read much of the data persistence code written in Swift.
