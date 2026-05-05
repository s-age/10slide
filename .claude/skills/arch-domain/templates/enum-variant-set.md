# Enum Variant Set Template

File: `Sources/Domain/Entities/{{Name}}.swift`

## With raw value and computed property

```swift
import Foundation

enum {{Name}}: String, Equatable, Sendable, CaseIterable, Codable {
    case {{case1}} = "{{rawValue1}}"
    case {{case2}} = "{{rawValue2}}"
    case {{case3}} = "{{rawValue3}}"

    var {{computedProperty}}: {{ReturnType}}? {
        switch self {
        case .{{case1}}: return {{value1}}
        case .{{case2}}: return {{value2}}
        case .{{case3}}: return nil
        }
    }
}
```

## Simple (no computed properties)

```swift
import Foundation

enum {{Name}}: String, Equatable, Sendable, CaseIterable, Codable {
    case {{case1}}
    case {{case2}}
    case {{case3}}

    static let `default` = {{Name}}.{{defaultCase}}
}
```

## Rules

- Conform to `String` (raw value), `Equatable`, `Sendable`, `CaseIterable`, `Codable`
- `CaseIterable` enables UI pickers in the Presentation layer
- `Codable` enables persistence without custom coding
- Provide `static let default` when a sensible default exists
- Computed properties return `Optional` when some cases have no meaningful value
- `import Foundation` only when computed properties use Foundation types
- Keep cases exhaustive — add new cases rather than catch-all defaults
