# Understanding SlideshowDomainService.swift

**Source file**: `Sources/Domain/Services/SlideshowDomainService.swift`

---

## Overview of This File

This is the implementation file for the **Domain Service** responsible for slideshow-related business logic (create, update, delete, fetch).
The role of this class is to hold **app-specific decisions** such as "what should happen when creating a slideshow?" and "is an existence check needed when updating?"

The complete source code is shown first. We will read through it from top to bottom, explaining the Swift concepts as they appear.

```swift
import Foundation

final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    private let repository: any SlideshowRepositoryProtocol

    init(repository: any SlideshowRepositoryProtocol) {
        self.repository = repository
    }

    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        let slideshow = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
        try await repository.save(slideshow)
        return slideshow
    }

    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
        try await repository.save(updated)
        return updated
    }

    func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.applying(config: config)
        try await repository.save(updated)
        return updated
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await repository.fetch(id: id)
    }

    func fetchAll() async throws -> [Slideshow] {
        try await repository.fetchAll()
    }
}
```

---

## Concept 1 -- `final class` + Protocol Conformance + `Sendable`

### Relevant Code

```swift
final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
```

### What Is `final class`?

`class` is a **reference type**. When assigned to a variable, what is passed is not the value itself but "where it lives (a reference)."
Adding `final` declares to the compiler that this class **cannot be inherited**.

### Why Use `final`?

- **Prohibiting inheritance makes the intent explicit.** It sends the message: "Use this class as-is; do not override it with a subclass."
- **It enables better compiler optimizations.** When `final` is present, the compiler can resolve method calls statically.

### What Would Happen Without `final`?

Someone could inherit from it with `class MySlideshowDomainService: SlideshowDomainService` and arbitrarily override the business logic. This becomes a breeding ground for unexpected behavior.

---

### What Is Protocol Conformance (`: SlideshowDomainServiceProtocol`)?

`SlideshowDomainServiceProtocol` is a **protocol** (= interface) that defines "the list of methods this class should have."
Writing `: SlideshowDomainServiceProtocol` declares "this class satisfies that protocol."

### Why Conform to a Protocol?

The upper layer (UseCase) only needs to know this **protocol** and does not need to know about the concrete class `SlideshowDomainService`.
During testing, it can be replaced with "a fake implementation that satisfies the protocol," enabling testing without a real database.

---

### What Is `Sendable`?

In Swift's concurrency model (async/await), multiple operations may run simultaneously.
`Sendable` is a marker protocol that guarantees "this type can be safely passed across multiple threads or asynchronous processing boundaries."

### Why Is It Needed Here?

`SlideshowDomainService` has `async` methods and is used across different asynchronous contexts.
By declaring `Sendable`, the Swift 6 compiler recognizes it as "a type that can be safely passed."

### What Would Happen Without `Sendable`?

The Swift 6 compiler would produce an error: "This type is not Sendable, so it cannot be passed across asynchronous boundaries."

---

## Concept 2 -- `private let repository: any SlideshowRepositoryProtocol`

### Relevant Code

```swift
private let repository: any SlideshowRepositoryProtocol
```

### What Are the `any` Keyword and Existential Types?

`any SlideshowRepositoryProtocol` is called an **existential type**.
It represents "some type that satisfies `SlideshowRepositoryProtocol`." You don't need to write a specific type name (e.g., `SwiftDataSlideshowRepository`).

Since Swift 5.7, the `any` keyword must be explicitly added to "existential types of protocols" like this. This makes it clear to the reader that "an existential type of a protocol is being used here, not a concrete type."

### What Is `private`?

`private` is an **access control** keyword. This property can only be read and written from within this class.

### What Is `let`?

Declaring with `let` makes it a **constant**. The `repository`, once set, cannot be changed.

### Why Write It This Way?

```swift
// NG -- Depends on a concrete type
private let repository: SwiftDataSlideshowRepository

// OK -- Depends on a protocol
private let repository: any SlideshowRepositoryProtocol
```

If you write the concrete type directly, you must also change this file when you want to swap the implementation for testing. Writing `any SlideshowRepositoryProtocol` means "anything that satisfies the protocol is accepted."

---

## Concept 3 -- Protocol-Based Dependency Injection

### Relevant Code

```swift
init(repository: any SlideshowRepositoryProtocol) {
    self.repository = repository
}
```

### What Is Dependency Injection?

It is a design pattern where the objects a class needs (= dependencies) are **provided from outside**.
`SlideshowDomainService` does not create a `SwiftDataSlideshowRepository()` itself.
Instead, it receives "something that satisfies the protocol" as an `init` argument.

### Why Use Dependency Injection?

| Situation | What to Pass |
|------|---------|
| Production environment | `SwiftDataSlideshowRepository` (the real DB) |
| Test environment | `MockSlideshowRepository` (an in-memory fake implementation) |

Since the caller decides "what to pass," the behavior can be switched without any changes to `SlideshowDomainService` itself.

### What Would Happen Without Dependency Injection?

```swift
// NG -- Creates a concrete implementation internally
init() {
    self.repository = SwiftDataSlideshowRepository()  // The real DB runs even during tests
}
```

The real database would run during tests, making tests slow and risking data contamination.

---

## Concept 4 -- `async throws` -- Asynchronous and Failable Functions

### Relevant Code

```swift
func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
    let slideshow = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
    try await repository.save(slideshow)
    return slideshow
}
```

### What Is `async`?

`async` is a marker indicating that "this function runs **asynchronously**."
Asynchronous means that while waiting for a time-consuming operation (such as saving to a database), other operations can proceed.

### What Is `throws`?

`throws` is a declaration that "this function **may throw an error**."
The caller must use `try` to handle the error.

### What Is `try await`?

```swift
try await repository.save(slideshow)
```

- `await` -- "Wait until this asynchronous operation completes"
- `try`  -- "This operation may fail, so prepare to propagate the error to the caller"

Using these two together lets you safely call "operations that are both asynchronous and may fail."

### What Would Happen Without `async throws`?

```swift
// NG -- Blocks synchronously (the UI freezes)
func create(...) -> Slideshow {
    repository.saveSync(slideshow)  // The entire app stops until the save finishes
    return slideshow
}
```

Since saving to a database takes time, waiting synchronously causes the app's UI to freeze.

---

## Concept 5 -- `guard let ... else { throw }` -- Safe Unwrapping of Optionals with Error Throwing

### Relevant Code

```swift
func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
    guard let existing = try await repository.fetch(id: id) else {
        throw DomainError.slideshowNotFound(id)
    }
    let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
    try await repository.save(updated)
    return updated
}
```

### What Is `Optional`?

`Slideshow?` (with a trailing `?`) is a type that represents "either a `Slideshow` exists or it doesn't (`nil`)."
`repository.fetch(id:)` returns `nil` when a slideshow with that ID does not exist in the database.

### What Is `guard let`?

`guard let existing = ... else { ... }` means:
- If a value exists, extract it into `existing` and continue execution
- If it is `nil`, enter the `else` block and exit the function there

The difference from regular `if let` is that `guard let` makes the intent of "early return when the condition is not met" explicit. The main processing when the condition is met continues without additional indentation, making it more readable.

### What Is `throw DomainError.slideshowNotFound(id)`?

When attempting to update a non-existent ID, silently ignoring the `nil` and continuing is dangerous.
By throwing an error with `throw`, you explicitly communicate "the slideshow with this ID was not found" to the caller.

### What Would Happen Without `guard let`?

```swift
// NG -- Force unwrapping the Optional (risk of crash)
let existing = try await repository.fetch(id: id)!
```

Force-unwrapping with `!` causes the app to crash when the value is `nil`.
Using `guard let`, you can return a meaningful error instead of crashing.

---

## Concept 6 -- The Role of a Domain Service

### What Is a Domain Service?

It is **"the place where app-specific decisions (business logic) are consolidated."**

For example, let's look at the `update` method.

```swift
func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
    guard let existing = try await repository.fetch(id: id) else {
        throw DomainError.slideshowNotFound(id)  // ← Business rule: cannot update what doesn't exist
    }
    let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
    try await repository.save(updated)
    return updated
}
```

"Always check for existence before updating" is not a database concern -- it is an app **rule**.
By writing this decision in the Domain Service, you can understand "why it behaves this way" in one place.

### What Would Happen Without a Domain Service?

Business logic would be scattered across view code (View) and data-saving code (Repository), making it impossible to tell "where and what is being decided." The same decisions would be duplicated in multiple places, and changes would inevitably lead to omissions.

### The Flow of This Service (Example: `update`)

```
1. repository.fetch(id:)   → Fetch existing data from the DB
2. guard let existing      → If it doesn't exist, throw an error and exit
3. existing.updating(...)  → Pure transformation on the Entity (business rule)
4. repository.save(updated)→ Save the transformed data to the DB
5. return updated          → Return the result to the caller
```

The characteristic of a Domain Service is that **a single method takes responsibility** for the entire flow of "fetch -> decide -> transform -> save -> return."

---

## Pitfalls Learned in Practice

Here is a pitfall from an issue that actually occurred during the development of this project involving Domain Services.

---

### Pitfall 1: A Domain Service Should Not Just "Transform and Return" -- It Must "Complete Persistence"

#### What Happens

If a Domain Service method only "transforms an entity and returns it" without calling `repository.save()`, callers (UseCases) can forget to save, resulting in bugs.

In an earlier iteration of this project, a Domain Service method only returned a transformed entity without calling `repository.save()`. On screen, the update appeared to be reflected (the ViewModel held the new value in memory), but when the app was restarted, the settings had reverted to their original values.

```swift
// ❌ Only transforms and returns (leaves saving to the caller)
func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow {
    guard let existing = try await repository.fetch(id: id) else {
        throw DomainError.slideshowNotFound(id)
    }
    return existing.applying(config: config)
    // Does not call repository.save()!
    // → If the caller forgets to save, data is lost on restart
}
```

```swift
// ✅ Complete fetch → transform → save → return in a single method
final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.applying(config: config)  // Transform
        try await repository.save(updated)                // Persist
        return updated                                    // Return
    }
}
```

#### Key Takeaways

- When a Domain Service method changes persistent state, **enclose all steps -- fetch, transform, save, return -- in a single method**
- When you see a method named `applyX` / `withX` / `applying(...)`, verify: "does this include saving?"
- Distinguish clearly in naming whether a method is a pure transformation or one that persists

---

## Summary: What You Can Learn from This File

| Concept | Key Point |
|------|------|
| `final class` | Prohibits inheritance, improving both intent clarity and performance |
| Protocol conformance | Upper layers need not know the concrete type, making replacement easy |
| `Sendable` | Declares that the type can be safely passed across asynchronous boundaries |
| `any SlideshowRepositoryProtocol` | An existential type. Treats a protocol as a type rather than a concrete type |
| `private let` | Encapsulation. Protects immutability by preventing external modification |
| Dependency injection (via `init`) | Enables swapping dependencies between production and test |
| `async throws` | Expresses asynchronous and failable operations in a type-safe manner |
| `try await` | The paired syntax for calling asynchronous + failable operations |
| `guard let ... else { throw }` | Safely unwraps an Optional, returning an error for early exit on nil |
| Domain Service | Gathers business rules in one place, making "why it behaves this way" clear |

These concepts form the fundamental patterns for writing **safe, changeable, and testable** code in Swift.
This file is only 46 lines long, but every single line has a reason behind "why it is written that way."
