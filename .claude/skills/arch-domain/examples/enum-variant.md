# Example: Enum Variant Set

A closed set of domain options with raw values and optional computed properties.

## Files to create

### 1. Enum with computed property — `Sources/Domain/Entities/SlideDuration.swift`

```swift
import Foundation

enum SlideDuration: String, Equatable, Sendable, CaseIterable, Codable {
    case five = "5"
    case ten = "10"
    case fifteen = "15"
    case thirty = "30"
    case sixty = "60"
    case manual

    var seconds: TimeInterval? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .thirty: return 30
        case .sixty: return 60
        case .manual: return nil
        }
    }
}
```

### 2. Simple enum with default — `Sources/Domain/Entities/TransitionType.swift`

```swift
import Foundation

enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve

    static let `default` = TransitionType.fade
}
```

## Key points

- `String` raw value — enables straightforward serialization
- `CaseIterable` — the Presentation layer uses `allCases` for picker UIs
- `Codable` — raw-value enums get automatic Codable conformance
- Computed properties return `Optional` when some cases have no meaningful value (e.g. `.manual` has no seconds)
- `static let default` — when one case is the natural starting choice
- No associated values — keeps enums simple and Codable-compatible
