---
paths:
  - 'Sources/Errors/**/*.swift'
---

## Role

Pure error type definitions accessible from **all layers**. This is a leaf-node layer — it depends only on `Foundation` and never imports from any other layer.

## Directory layout

```
Errors/
├── DomainError.swift       # Business-rule violations (not found, invalid state)
└── ValidationError.swift   # Request validation failures
```

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation` | Everything else — `SwiftUI`, `UIKit`, `SwiftData`, `Photos`, `Domain`, `UseCases`, `Repositories`, `Infrastructure`, `Presentation` |

## Patterns

All error enums conform to `LocalizedError` + `Sendable` and provide `errorDescription`:

```swift
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

## Constraints

- Associated values must be `Foundation` types only (`UUID`, `String`, `Int`, etc.) — never Entity or DTO types
- No business logic — error enums are pure data declarations with display strings
- No protocol definitions — errors are concrete enums, not abstractions
- Keep enums focused: one enum per failure domain, not one monolithic `AppError`

## Prohibitions

- Never import from any other layer in the project
- Never add methods beyond `LocalizedError` requirements
- Never store reference types in associated values
