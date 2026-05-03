---
paths:
  - 'Sources/Domain/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/Domain/`:

- **Layer responsibility**: Pure Swift value types that model business concepts. No I/O, no UI, no persistence framework dependencies. All layers may import from here.
- **Import allowlist**: `Foundation` only — never `SwiftData`, `Photos`, `SwiftUI`, `UIKit`, or any infrastructure framework.

## Patterns

**Entity — `struct` conforming to `Identifiable`, `Equatable`, `Sendable`; closed variant sets use `enum`**

```swift
// Good
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String
    var order: Int
    var duration: TimeInterval
    var title: String?   // optional fields use ? only when value is legitimately absent
}

// Bad — class entity, or missing Sendable
class Slide: Identifiable {   // NG: should be struct
    var id: UUID
}
```

**`nil` vs `Optional`**: Use `?` on entity fields only when a value may legitimately be absent at the domain level (e.g. `title`). Avoid `Optional` to model "not yet loaded" — that is a ViewModel concern.

## Prohibitions

- Never import `SwiftData`, `Photos`, `SwiftUI`, or `UIKit` — enforced by SwiftLint
- Never add persistence annotations (`@Model`, `@Attribute`) — those belong in `Infrastructure/SwiftData/DTO/`
- Never use `class` for entities — all domain types are `struct` or `enum` (value types only)
- Never hold references to repository or infrastructure types
- Never add computed UI formatters — keep entities free of display concerns
