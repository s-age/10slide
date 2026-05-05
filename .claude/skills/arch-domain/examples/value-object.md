# Example: Value Object

A configuration struct without unique identity, grouping related settings.

## Files to create

### 1. Value Object — `Sources/Domain/Entities/SlideshowConfig.swift`

```swift
import Foundation

struct SlideshowConfig: Equatable, Sendable, Codable {
    var duration: SlideDuration
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(
        duration: .five,
        transition: .fade,
        loop: true
    )
}
```

## Key points

- No `id: UUID` — identity is irrelevant; equality is structural
- No `Identifiable` conformance — distinguishes value objects from entities
- `Codable` — enables serialization for persistence without custom coding
- `static let default` — provides a sensible starting configuration
- All fields are `var` — the owning entity mutates configs via `applying(config:)`
- References other Domain types (`SlideDuration`, `TransitionType`) directly
