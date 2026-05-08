# Error Design Guide — Handling Errors in a Layered Architecture

**Category:** Advanced (Cross-Topic Guide)

In a layered architecture, the guiding principle is "never leak types across layer boundaries." However, errors inherently cross layers. An error that originates in the Domain layer must ultimately be displayed to the user in the Presentation layer.

This guide explains the error design patterns adopted by 10slide and the reasoning behind those decisions.

---

## Overview

10slide's error design originally followed a "define error types per layer and map them at boundaries" approach. However, the following problems emerged in practice, leading to a migration to the current "shared leaf layer" approach.

| Approach | Advantages | Disadvantages |
|----------|-----------|---------------|
| Per-layer error types | Strict layer boundaries | Dead code, duplicate cases, `LocalizedError` omissions |
| Shared leaf layer (current) | Simple, `LocalizedError` guaranteed | Errors cross layers (an intentional exception) |

---

## 1. The Errors Directory Is a "Shared Leaf Layer" — Accessible from All Layers

### What is this?

`Sources/Errors/` is the **sole exception** in 10slide's layered architecture. Normally, each layer can only communicate with its immediate neighbor, but `Errors/` is **directly accessible from all layers**.

```
Presentation → UseCases → Domain/Services → Repositories → Infrastructure
                              ↑                   ↑              ↑
                          Errors/ ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
                   (Shared leaf layer: accessible from all layers)
```

### Why this design?

#### Problem 1: Dead code

Creating error types per layer leads to unused cases.

```swift
// ❌ UseCaseError mirrors all DomainError cases, but Presentation only uses some
enum UseCaseError: Error {
    case slideshowNotFound       // Used
    case invalidSlideOrder       // Used
    case databaseCorruption      // Not used in Presentation — dead code
    case networkTimeout          // Not used in Presentation — dead code
}
```

#### Problem 2: Missing LocalizedError conformance

If `DomainError` does not conform to `LocalizedError`, then when displaying the error to the user in Presentation, `error.localizedDescription` returns the meaningless string `"The operation couldn\u{2019}t be completed."`.

```swift
// ❌ DomainError does not conform to LocalizedError
enum DomainError: Error {
    case slideshowNotFound
}
// In Presentation: error.localizedDescription → meaningless generic message
```

#### Problem 3: Placement confusion

Deciding which layer to place error types in caused confusion. Placing `UseCaseError` in `UseCases/Requests/` was semantically unnatural.

### Actual error types in this project

```swift
// Sources/Errors/DomainError.swift
enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .slideshowNotFound(let id):
            return String(localized: "Slideshow not found: \(id.uuidString)")
        }
    }
}

// Sources/Errors/ValidationError.swift
enum ValidationError: LocalizedError, Sendable {
    case emptyName
    case noIdentifiers
    case invalidIndex
    case noSlides

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return String(localized: "Name must not be empty")
        case .noIdentifiers:
            return String(localized: "At least one image must be selected")
        case .invalidIndex:
            return String(localized: "Slide index is out of range")
        case .noSlides:
            return String(localized: "Slideshow has no slides")
        }
    }
}
```

Note three conventions:
1. **`LocalizedError, Sendable`** — both are required. `Sendable` is needed because errors cross actor boundaries in Swift 6.
2. **`String(localized:)`** — enables future localization instead of hardcoded strings.
3. **No argument labels** — `case slideshowNotFound(UUID)`, not `case slideshowNotFound(id: UUID)`.

### Incorrect example

```swift
// ❌ Creating error types per layer — a breeding ground for duplication and dead code
// Sources/Domain/Services/DomainError.swift
enum DomainError: Error {
    case slideshowNotFound(UUID)
}

// Sources/UseCases/Requests/UseCaseError.swift
enum UseCaseError: Error {
    case slideshowNotFound(UUID)  // Copy of DomainError
}
```

### Rules

- All error enums must be placed in `Sources/Errors/`
- Create one enum per failure domain (`DomainError`, `ValidationError`, etc.)
- Do not create a monolithic `AppError` — it will bloat over time
- Do not place business logic or protocols in `Sources/Errors/` — only pure error definitions

---

## 2. Why Error Conversion at Layer Boundaries Is Unnecessary

### Previous design (per-layer error types)

Previously, the approach was to "convert Domain errors to `UseCaseError` at the UseCase boundary and expose only `UseCaseError` to Presentation."

```swift
// Previous approach — converting DomainError → UseCaseError within the UseCase
func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    do {
        let slideshow = try await domainService.create(name: request.name, localIdentifiers: request.localIdentifiers, config: ...)
        return SlideshowResponse(from: slideshow)
    } catch let error as DomainError {
        switch error {
        case .slideshowNotFound(let id):
            throw UseCaseError.slideshowNotFound(id)  // Re-defining the same case
        // ... mapping all other cases as well
        }
    }
}
```

### Current design (shared leaf layer)

Errors are thrown directly using enums from `Sources/Errors/`. No inter-layer mapping is needed.

```swift
// ✅ Current approach — errors use the Sources/Errors/ types as-is
func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    // Note: validate() is handled by ValidationAsyncUseCaseDecorator in the DI layer
    let config = SlideshowConfig(
        duration: request.duration.toDomain,
        transition: request.transition.toDomain,
        loop: request.loop
    )
    let slideshow = try await domainService.create(
        name: request.name,
        localIdentifiers: request.localIdentifiers,
        config: config
    )
    return SlideshowResponse(from: slideshow)
    // DomainError (e.g. .slideshowNotFound) propagates directly without conversion
}
```

### Why are errors an exception?

The principle "don't leak types across layers" is meant to protect **Entities (business data)**. Entities carry structure and behavior, and depending on them creates layer coupling. Errors, on the other hand, are **pure signals**.

| Type category | Cross-layer sharing | Reason |
|---------------|-------------------|--------|
| Entity (Slideshow, Slide) | Forbidden | Carries structure and behavior, creates layer coupling |
| Response DTO | UseCase → Presentation only | Display data specific to Presentation |
| Error enum | Shared across all layers | Pure signal, no dependencies beyond Foundation |

---

## 3. Design Principles for Error Types

### Principle 1: Conform to both `LocalizedError` and `Sendable`

```swift
// ✅ Both conformances required
enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .slideshowNotFound(let id):
            return String(localized: "Slideshow not found: \(id.uuidString)")
        }
    }
}
```

```swift
// ❌ Missing Sendable — compile error when thrown across actor boundaries in Swift 6
enum DomainError: LocalizedError {
    case slideshowNotFound(UUID)
}

// ❌ Missing LocalizedError — localizedDescription returns a meaningless generic message
enum DomainError: Error, Sendable {
    case slideshowNotFound(UUID)
}
// error.localizedDescription → "The operation couldn't be completed."
```

### Principle 2: Use `String(localized:)` for error messages

```swift
// ✅ Enables future localization
var errorDescription: String? {
    switch self {
    case .slideshowNotFound(let id):
        return String(localized: "Slideshow not found: \(id.uuidString)")
    }
}
```

```swift
// ❌ Hardcoded strings — no localization support
var errorDescription: String? {
    switch self {
    case .slideshowNotFound(let id):
        return "Slideshow not found (ID: \(id))"
    }
}
```

### Principle 3: No imports other than Foundation

Files in `Sources/Errors/` may **only** import Foundation. Importing other frameworks (SwiftUI, SwiftData, etc.) or types from other layers breaks the "shared leaf layer" premise.

```swift
// ✅ Foundation only
import Foundation

enum ValidationError: LocalizedError, Sendable {
    case emptyName           // No associated value needed
    case invalidIndex        // Primitive case
}
```

```swift
// ❌ Importing SwiftData — introduces an Infrastructure dependency into the Errors layer
import SwiftData

enum DataError: LocalizedError, Sendable {
    case modelNotFound(PersistentIdentifier)  // Using a SwiftData type as an associated value
}
```

### Principle 4: Do not use Entities or DTOs as associated values

```swift
// ✅ Primitive/Foundation types only
enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)    // UUID is a Foundation type
}
```

```swift
// ❌ Using an Entity as an associated value — creates layer coupling
enum DomainError: LocalizedError, Sendable {
    case invalidSlideshow(Slideshow)  // Dependency on a Domain Entity
}
```

### Principle 5: One enum per failure domain

```swift
// ✅ Split by domain — this project uses:
enum DomainError: LocalizedError, Sendable { /* Business-rule violations */ }
enum ValidationError: LocalizedError, Sendable { /* Request validation failures */ }
```

```swift
// ❌ Cramming everything into one — bloats and becomes unmanageable
enum AppError: LocalizedError, Sendable {
    case slideshowNotFound
    case emptyName
    case photoAccessDenied
    case networkTimeout
    // ... grows without end
}
```

---

## Summary

| Principle | Details |
|-----------|---------|
| Placement | `Sources/Errors/` — shared leaf layer |
| Protocol conformance | All enums conform to `LocalizedError, Sendable` |
| Error messages | Use `String(localized:)` for localization support |
| Import restriction | `Foundation` only — other frameworks are forbidden |
| Associated values | Primitive/Foundation types only — Entities/DTOs are forbidden |
| Granularity | One enum per failure domain (`DomainError`, `ValidationError`) — monolithic `AppError` is forbidden |
| Inter-layer mapping | Not needed — errors use the shared leaf layer types directly |
| Business logic | Do not place in `Sources/Errors/` — only pure error definitions |

### "Why do we forbid leaking Entities but allow Errors?"

Entities carry structure and behavior, and depending on them strengthens coupling between layers. Errors are pure signals that carry only enum case names and `LocalizedError` messages, and they do not increase inter-layer coupling. This distinction is the rationale behind the "shared leaf layer" design.
