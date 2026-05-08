# Repository Pattern and SwiftData Swift Fundamentals

> Audience: People who are just starting to learn Swift. Those who read code and wonder "why is it written this way?"

---

## Target Source File and Overview

| File | Type Category | Role |
|---|---|---|
| `Sources/Repositories/Implementations/SlideshowRepository.swift` | Repository (implementation class) | Handles persistence, retrieval, and deletion of slideshows |

This file belongs to the **Repository layer**. The Repository layer's job is to hide the technical details of "where and how data is stored," passing only simple Swift types (entities) to the upper layers (Domain / UseCases).

---

## Full Source Code (for reference)

```swift
import Foundation
import SwiftData

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    init(store: any SwiftDataStoreProtocol) {
        self.store = store
    }

    func fetchAll() async throws -> [Slideshow] {
        try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await store.fetch(
            FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        ) { [self] in slideshow(from: $0) }.first
    }

    func save(_ slideshow: Slideshow) async throws {
        let id = slideshow.id
        let name = slideshow.name
        let createdAt = slideshow.createdAt
        let durationRawValue = slideshow.config.duration.rawValue
        let transitionRawValue = slideshow.config.transition.rawValue
        let loop = slideshow.config.loop
        let slides = slideshow.slides

        try await store.write { context in
            let newSlides = slides.map {
                SlideModel(
                    id: $0.id,
                    localIdentifier: $0.localIdentifier,
                    order: $0.order,
                    duration: $0.duration,
                    title: $0.title
                )
            }
            let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.durationRawValue = durationRawValue
                existing.transitionRawValue = transitionRawValue
                existing.loop = loop
                existing.slides.forEach { context.delete($0) }
                newSlides.forEach { context.insert($0) }
                existing.slides = newSlides
            } else {
                let model = SlideshowModel(
                    id: id,
                    name: name,
                    createdAt: createdAt,
                    durationRawValue: durationRawValue,
                    transitionRawValue: transitionRawValue,
                    loop: loop
                )
                context.insert(model)
                newSlides.forEach { context.insert($0) }
                model.slides = newSlides
            }
            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
    }

    // MARK: - Private

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

---

## Concept-by-Concept Explanation

---

### 1. The Repository Pattern -- Why Abstract Data Access

#### Definition

The **Repository pattern** is a design pattern that separates the technical details of "how data is read and written" from the application's business logic.

In this app, the protocol `SlideshowRepositoryProtocol` defines "what can be done (the interface)," and `SlideshowRepository` handles the implementation.

```swift
// Protocol (defined in the Protocols/ layer) -- declares only "what can be done"
protocol SlideshowRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slideshow]
    func fetch(id: UUID) async throws -> Slideshow?
    func save(_ slideshow: Slideshow) async throws
    func delete(id: UUID) async throws
}

// Implementation (in the Implementations/ layer) -- defines "how it's done"
final class SlideshowRepository: SlideshowRepositoryProtocol { ... }
```

#### Why It's Used Here

The Domain and UseCases layers simply say "please fetch the slideshows." They don't need to know where the data is stored -- whether it's SwiftData, a file, or the network. The Repository bridges that gap.

#### About `any SwiftDataStoreProtocol`

```swift
private let store: any SwiftDataStoreProtocol
```

The `any` keyword marks this as an **existential type** — "a box that can hold any type conforming to `SwiftDataStoreProtocol`." This allows the Repository to work with any implementation of the store (e.g., a real `SwiftDataStore` in production, or a mock in tests) without knowing the concrete type.

#### About `@Relationship(deleteRule: .cascade)`

The `SlideshowModel` (defined in `Repositories/Models/`) uses:

```swift
@Relationship(deleteRule: .cascade, inverse: \SlideModel.slideshow) var slides: [SlideModel]
```

This means: when a `SlideshowModel` is **deleted**, all its child `SlideModel`s are automatically deleted too. That's why the `delete(id:)` method only needs `store.delete(SlideshowModel.self, ...)` without manually deleting children. However, `cascade` does **not** trigger on relationship **reassignment** — that's why `save()` explicitly calls `context.delete($0)` on old slides before assigning new ones.

#### What If the Repository Pattern Weren't Used

```swift
// Bad: UseCase directly manipulates SwiftData
final class FetchSlideshowsUseCase {
    private let context: ModelContext  // SwiftData knowledge leaks into the UseCase

    func execute() throws -> [Slideshow] {
        let models = try context.fetch(FetchDescriptor<SlideshowModel>())
        // ... conversion logic ends up inside the UseCase too
    }
}
```

- You'd need to set up a real database for testing
- Switching SwiftData to a different database would require rewriting the UseCase as well
- Separation of concerns breaks down, and the code becomes complex

#### Relevant Code

```swift
final class SlideshowRepository: SlideshowRepositoryProtocol {
    // By conforming to the protocol, upper layers can only access it through the protocol
```

---

### 2. `import SwiftData` -- The SwiftData Framework

#### Definition

`import SwiftData` is a declaration that loads Apple's data persistence framework. With SwiftData, you can save and retrieve data to a database (SQLite) simply by annotating a Swift `class` with `@Model`.

#### Why It's Used Here

`SlideshowRepository` uses `SlideshowModel` (a SwiftData `@Model` class) to read and write data, so the SwiftData framework is required.

#### What If You Didn't Import It

```swift
// Bad: Without the import, FetchDescriptor and #Predicate cause compile errors
FetchDescriptor<SlideshowModel>()  // error: cannot find type 'FetchDescriptor'
```

#### Relevant Code

```swift
import Foundation
import SwiftData   // Needed to use SlideshowModel, FetchDescriptor, and #Predicate
```

> **Key point**: The `import` for SwiftData is only permitted in the Repository layer. It is forbidden in Domain and UseCase layers. This enforces the rule that "upper layers don't need to know about persistence details."

---

### 3. `FetchDescriptor<T>` -- A Fetch Descriptor Using Generics

#### Definition

`FetchDescriptor<T>` is a type that represents "which model to fetch and under what conditions." The `<T>` part is **generics**, where you substitute a concrete type (here, `SlideshowModel`) for `T`.

Generics is a mechanism for "treating types like variables." `FetchDescriptor` itself is a generic concept of "a fetch descriptor," and by writing `<SlideshowModel>`, it becomes a concrete type meaning "a fetch descriptor for retrieving `SlideshowModel`."

#### Why It's Used Here

SwiftData needs to know at compile time which model to fetch. By writing `FetchDescriptor<SlideshowModel>`, you can create a "query configuration for fetching `SlideshowModel`" in a type-safe way.

```swift
// No arguments -- fetch all slideshows
FetchDescriptor<SlideshowModel>()

// With a predicate -- fetch only those matching the condition
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
```

#### What If There Were No Type Parameter (`<T>`)

```swift
// Bad: Without generics (hypothetical example)
FetchDescriptor(modelType: SlideshowModel.self)
// The return type would be [Any], so the compiler can't verify types
// You wouldn't notice mistakes until a runtime error occurs
```

#### Relevant Code

```swift
// fetchAll: Fetch all records
try await store.fetch(FetchDescriptor<SlideshowModel>()) { ... }
//                               ^^^^^^^^^^^^^^^^
//                         Generics specifies the type to fetch

// fetch(id:): Conditional fetch
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
```

---

### 4. `#Predicate { }` -- Macro-Based Predicate Expressions

#### Definition

`#Predicate` is a Swift macro (a mechanism that generates code). When you write a "condition expression" in Swift inside the closure, the compiler converts it into a database query.

#### Why It's Used Here

It's used when you want to fetch only slideshows with a specific `id`. `#Predicate { $0.id == id }` represents the condition "records whose `id` property equals the variable `id`."

```swift
// Condition to fetch only slideshows with a matching id
#Predicate { $0.id == id }
```

Because this macro is written as Swift code, IDE autocompletion works, and type checking is performed at compile time.

#### What If `#Predicate` Weren't Used

```swift
// Bad: Writing SQL as a string (the old CoreData approach)
NSPredicate(format: "id == %@", id as CVarArg)
// IDE autocompletion doesn't work because it's a string
// Typos aren't caught until runtime
// The compiler can't verify whether "id" is an actual property name
```

#### Relevant Code

```swift
// fetch(id:) -- fetch only a specific ID
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
//                                         ^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                         A type-safe query written as Swift code

// delete(id:) -- delete only a specific ID
store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
```

---

### 5. `$0` -- Closure Shorthand Argument Names

#### Definition

Closure (anonymous function) arguments can be given names, but they can also be referenced using the **shorthand forms** `$0`, `$1`, `$2`, and so on. `$0` means "the first argument."

```swift
// With a named parameter (verbose but clear)
{ model in slideshow(from: model) }

// Using $0 shorthand (compact)
{ slideshow(from: $0) }
```

#### Why It's Used Here

In contexts like `#Predicate { }` or `.map { }`, the closure's argument is obvious, so `$0` lets you write it concisely.

```swift
// $0 = each SlideshowModel element returned by FetchDescriptor
{ [self] in slideshow(from: $0) }

// $0 = each Slide element in the slides array
slides.map {
    SlideModel(
        id: $0.id,              // Slide's id
        localIdentifier: $0.localIdentifier,
        order: $0.order,
        duration: $0.duration,
        title: $0.title
    )
}
```

#### What If `$0` Weren't Used

```swift
// Explicit argument name is slightly more verbose
slides.map { slide in
    SlideModel(
        id: slide.id,
        localIdentifier: slide.localIdentifier,
        order: slide.order,
        duration: slide.duration,
        title: slide.title
    )
}
// The behavior is the same. The named argument slide may be more readable depending on context
```

#### Relevant Code

```swift
// Inside #Predicate
#Predicate { $0.id == id }
//           ^^ The SlideshowModel instance being fetched

// Inside map (save)
slides.map {
    SlideModel(id: $0.id, ...)
//             ^^ Each Slide element in the slides array

// Inside sorted (slideshow(from:))
model.slides.sorted { $0.order < $1.order }
//                    ^^         ^^ The two SlideModel instances being compared
```

---

### 6. `[self]` Capture List -- Closure Captures

#### Definition

Closures can "capture" variables from their surrounding scope. A **capture list** (`[self]`, `[weak self]`, etc.) is syntax that explicitly declares "what to capture and how."

```swift
{ [self] in slideshow(from: $0) }
//^^^^^^^
// "Capture self (this class's instance) by value"
```

#### Why It's Used Here

The transform closure of `store.fetch(...)` is **executed across SwiftData's actor boundary**. At that point, the Swift 6 compiler requires you to explicitly state "how to handle `self`."

By writing `[self]`, you declare "use `self` as it exists when the closure executes," which prevents compile errors.

#### What If `[self]` Were Omitted

```swift
// Bad: Without [self]
try await store.fetch(FetchDescriptor<SlideshowModel>()) { in slideshow(from: $0) }
// In Swift 6, you may get errors like "Capture of 'self' with non-sendable type"
```

`[self]` is used instead of `[weak self]` because the Repository class is long-lived and won't be deallocated while the closure is executing.

#### Relevant Code

```swift
func fetchAll() async throws -> [Slideshow] {
    try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
    //                                                         ^^^^^^
    //                    Explicitly captures self (SlideshowRepository)
}
```

---

### 7. Trailing Closure Syntax -- When the Last Argument Is a Closure

#### Definition

In Swift, when a function's **last argument is a closure**, you can use "trailing closure syntax" to write the closure outside the `()`.

```swift
// Standard call (with label)
store.fetch(FetchDescriptor<SlideshowModel>(), transform: { [self] in slideshow(from: $0) })

// Trailing closure syntax (write the last argument outside the ())
store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
```

#### Why It's Used Here

When a closure is long, writing it outside the `()` makes the code structure easier to read.

```swift
// Trailing closure for store.write (multi-line)
try await store.write { context in
    // ... multiple lines of code ...
    try context.save()
}
// The { } indicates "this is the argument to store.write" while keeping indentation natural
```

#### What If Trailing Closure Syntax Weren't Used

```swift
// Without trailing closure (deeper nesting makes it harder to read)
try await store.write(body: { context in
    // ...
    try context.save()
})
```

#### Relevant Code

```swift
// When it fits on a single line
try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
//                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                                      The closure is written outside the ()

// When it spans multiple lines
try await store.write { context in
    // ...
}
```

---

### 8. `.map { }`, `.sorted { }`, `.first` -- Collection Operations

#### Definition

Swift's arrays (`Array`) come with built-in convenience methods for transforming, filtering, and aggregating elements.

| Method | Meaning |
|---|---|
| `.map { }` | Transforms each element and creates a new array |
| `.sorted { }` | Creates a new array sorted according to a condition |
| `.first` | Returns the first element (or `nil` if none) |
| `.forEach { }` | Executes an operation on each element (no return value) |

#### Why They're Used Here

**`.map { }`** -- For converting between `Slide` (entity) and `SlideModel` (SwiftData model), and vice versa.

```swift
// Slide entity -> SlideModel conversion (during save)
let newSlides = slides.map {
    SlideModel(id: $0.id, localIdentifier: $0.localIdentifier, ...)
}

// SlideModel -> Slide entity conversion (inside slideshow(from:))
.map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, ...) }
```

**`.sorted { }`** -- For sorting slides by `order` (display order). Because the database doesn't guarantee retrieval order, we sort explicitly.

```swift
model.slides.sorted { $0.order < $1.order }
//           ^^^^^^^ Sort in ascending order by order
```

**`.first`** -- For getting only the first item from a `FetchDescriptor` result. Since `fetch` returns an array, `.first` extracts a single element as an Optional (which may be `nil`).

```swift
try await store.fetch(...) { ... }.first
//                               ^^^^^^ The first element of the array. nil if not found
```

#### What If `.map { }` Weren't Used

```swift
// Manual conversion with a for loop
var newSlides: [SlideModel] = []
for slide in slides {
    let model = SlideModel(id: slide.id, localIdentifier: slide.localIdentifier, ...)
    newSlides.append(model)
}
// The behavior is the same, but the intent of "converting an array to an array of another type" is less clear than with .map
```

#### Relevant Code

```swift
// Inside slideshow(from:) -- chaining .sorted and .map
let slides = model.slides
    .sorted { $0.order < $1.order }   // 1. Sort by order
    .map { Slide(id: $0.id, ...) }    // 2. Convert SlideModel -> Slide entity

// fetch(id:) -- get a single Optional result with .first
} { [self] in slideshow(from: $0) }.first

// Inside save -- .forEach for batch insert/delete
existing.slides.forEach { context.delete($0) }
newSlides.forEach { context.insert($0) }
```

---

### 9. `context.insert()`, `context.delete()`, `context.save()` -- SwiftData CRUD

#### Definition

SwiftData's `ModelContext` (the variable named `context`) is "a workspace that temporarily records changes to the database." Rather than writing changes to disk immediately, you first perform operations on the `context`, then call `save()` at the end to commit them all at once.

| Method | Role |
|---|---|
| `context.insert(model)` | Adds a model to the database (Create) |
| `context.fetch(descriptor)` | Retrieves models matching conditions (Read) |
| `context.delete(model)` | Removes a model from the database (Delete) |
| `context.save()` | Commits all changes to disk |

#### Why It's Used Here

By calling `save()` at the very end, if an error occurs midway, all changes are rolled back. This is called an **atomic operation** ("either all succeed or all fail").

```swift
try await store.write { context in
    // If an existing record is found, update it; otherwise, create a new one (Upsert pattern)
    if let existing = try context.fetch(descriptor).first {
        existing.name = name          // 1. Update properties
        existing.slides.forEach { context.delete($0) }   // 2. Delete old slides
        newSlides.forEach { context.insert($0) }         // 3. Add new slides
        existing.slides = newSlides
    } else {
        let model = SlideshowModel(...)
        context.insert(model)         // 1. Add a new record
        newSlides.forEach { context.insert($0) }
        model.slides = newSlides
    }
    try context.save()               // This is where data is actually written to disk
}
```

#### What If `save()` Weren't Called

```swift
// Bad: If you forget save(), changes aren't persisted to disk
try await store.write { context in
    context.insert(model)
    // try context.save() -- forgot!
    // Data disappears when the app is restarted
}
```

#### Relevant Code

```swift
try await store.write { context in
    // ...
    existing.slides.forEach { context.delete($0) }  // Delete old slides
    newSlides.forEach { context.insert($0) }         // Add new slides
    // ...
    try context.save()  // Commit changes to disk. Throws on error
}
```

---

### 10. Copying Variables Before `save()` -- Safely Passing Values to Closures

#### Definition

The closure in `store.write { context in ... }` is **executed across SwiftData's actor boundary**. In Swift 6, closures that cross actor boundaries must be `Sendable`, and directly referencing `self`'s properties inside the closure may cause compile errors.

For this reason, all necessary values are copied to local variables at the beginning of the `save()` method.

```swift
func save(_ slideshow: Slideshow) async throws {
    // Copy values before passing to the closure
    let id = slideshow.id
    let name = slideshow.name
    let createdAt = slideshow.createdAt
    let durationRawValue = slideshow.config.duration.rawValue
    let transitionRawValue = slideshow.config.transition.rawValue
    let loop = slideshow.config.loop
    let slides = slideshow.slides    // Everything above is a copy

    try await store.write { context in
        // Inside the closure, use the copied values instead of self
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        // ...
    }
}
```

#### Why It's Used Here

`Slideshow` conforms to `Sendable`, so it can be passed directly to a closure. However, across SwiftData's actor boundary, passing "raw values" is safer and simpler than accessing through `self` (`SlideshowRepository`). In particular, the `#Predicate` macro captures variables, so passing `Sendable` value types is the reliable approach.

#### What If You Tried to Use `self.slideshow` Directly Without Copying

```swift
// Bad: Trying to use self inside the closure
try await store.write { context in
    // #Predicate may not be able to capture self.slideshow.id
    let descriptor = FetchDescriptor<SlideshowModel>(
        predicate: #Predicate { $0.id == self.slideshow.id }  // Possible compile error
    )
}
```

#### Relevant Code

```swift
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id                            // Copy a value type (UUID)
    let name = slideshow.name                        // Copy a value type (String)
    let durationRawValue = slideshow.config.duration.rawValue   // Copy a value type
    // ... copy all properties

    try await store.write { context in
        // Inside the closure, all copied value types are used
        #Predicate { $0.id == id }                   // Uses the copied id
    }
}
```

---

## Summary: What You Can Learn from This File

### Swift Language Fundamentals

| Concept | What You Learned |
|---|---|
| `import SwiftData` | Loading a framework. An import permitted only in the Repository layer |
| Generics `<T>` | A mechanism for treating types like variables. `FetchDescriptor<SlideshowModel>` specifies the fetch target in a type-safe way |
| `$0` | Closure shorthand argument name. Commonly used in array operations and `#Predicate` |
| `[self]` capture list | Explicitly states how to handle `self` in closures that cross actor boundaries |
| Trailing closure | When the last argument is a closure, it can be written outside the `()`. Makes long operations more readable |

### Collection Operations

| Method | Usage |
|---|---|
| `.map { }` | Type conversion. Used for converting between `SlideModel` and `Slide` |
| `.sorted { }` | Sorting. Arranges slides in `order` property sequence |
| `.first` | Gets the first element as an Optional. Used to extract a single result from an ID search |
| `.forEach { }` | Repetition with side effects. Used for batch `insert` / `delete` operations |

### SwiftData CRUD

| Operation | Method | Characteristics |
|---|---|---|
| Create | `context.insert(model)` | Adds a model to the DB |
| Read | `context.fetch(descriptor)` | Conditional retrieval |
| Update | Property assignment | `@Model` classes are reference types, so they can be modified directly |
| Delete | `context.delete(model)` | Removes a model from the DB |
| Commit | `context.save()` | Writes changes to disk. Must always be called at the end |

### The 3 Principles of the Repository Pattern

1. **Upper layers only know about entities** -- `SlideshowModel` (SwiftData's internal type) is never exposed outside the Repository
2. **All conversion happens inside the Repository** -- `@Model <-> Entity` conversion logic is centralized in one place
3. **Implementation is hidden behind a protocol** -- Callers operate only through `SlideshowRepositoryProtocol` and don't need to know about SwiftData details

### Position in the Architecture

```
Presentation
    |
UseCases  <- Requests "save the slideshow" through the Repository protocol
    |
Domain/Services
    |
Repositories  <- <- <- <- This is where SlideshowRepository lives
    |
Infrastructure (SwiftData's ModelContext)
```

The Repository layer serves as a bridge between "the promise to upper layers (return entities)" and "the delegation to lower layers (persist with SwiftData)."
