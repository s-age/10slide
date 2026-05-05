---
paths:
  - 'Sources/Domain/Entities/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/Domain/Entities/`:

- **Layer responsibility**: Pure Swift value types that model business concepts. No I/O, no UI, no persistence framework dependencies. Domain/Services and all upper layers may import from here.
- **Import allowlist**: `Foundation` only — never `SwiftData`, `Photos`, `SwiftUI`, `UIKit`, or any infrastructure framework.

## Patterns

**Entity — `struct` conforming to `Identifiable`, `Equatable`, `Sendable`**

Primary domain objects with a unique identity (`id: UUID`).

```swift
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String
    var order: Int
    var duration: TimeInterval
    var title: String?   // optional fields use ? only when value is legitimately absent
}
```

**Value Object — `struct` conforming to `Equatable`, `Sendable`; optionally `Codable`**

Configuration or composite values without unique identity.

```swift
struct SlideshowConfig: Equatable, Sendable, Codable {
    var duration: SlideDuration
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(duration: .five, transition: .fade, loop: true)
}
```

**Enum Variant Set — `enum` conforming to `String`, `Equatable`, `Sendable`, `CaseIterable`, `Codable`**

Closed sets of domain-level options backed by a raw value.

```swift
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve

    static let `default` = TransitionType.fade
}
```

**Factory Method — `static func create(...)` on the Entity**

Encapsulates entity construction rules within the domain.

```swift
static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
    Slideshow(
        id: UUID(),
        name: name,
        slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
        config: config,
        createdAt: Date()
    )
}
```

**Immutable Update — `func applying(...) -> Self` / `func updating(...) -> Self`**

Returns a new copy with modified fields. Keeps entities free of mutation side-effects.

```swift
func applying(config: SlideshowConfig) -> Slideshow {
    var updated = self
    updated.config = config
    return updated
}
```

## Allowed additional conformances

- `Codable` — for types that cross serialization boundaries (configs, enums)
- `CaseIterable` — for enums used in UI pickers
- `Identifiable` — for types with a unique `id`

## `nil` vs `Optional`

Use `?` on entity fields only when a value may legitimately be absent at the domain level (e.g. `title`). Avoid `Optional` to model "not yet loaded" — that is a ViewModel concern.

## Prohibitions

- Never import `SwiftData`, `Photos`, `SwiftUI`, or `UIKit` — enforced by SwiftLint
- Never add persistence annotations (`@Model`, `@Attribute`) — those belong in `Infrastructure/SwiftData/DTO/`
- Never use `class` for entities — all domain types are `struct` or `enum` (value types only)
- Never hold references to repository or infrastructure types
- Never add computed UI formatters — keep entities free of display concerns
