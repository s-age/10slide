# Response Enum Template

File: `Sources/UseCases/Responses/{{Name}}Response.swift`

```swift
import Foundation

enum {{Name}}Response: String, Equatable, Sendable, CaseIterable {
    case {{case1}} = "{{rawValue1}}"
    case {{case2}} = "{{rawValue2}}"

    var {{computedProperty}}: {{ReturnType}}? {
        switch self {
        case .{{case1}}: return {{value1}}
        case .{{case2}}: return {{value2}}
        }
    }
}
```

## Rules

- Conform to `Sendable`, `Equatable`, `CaseIterable`
- Use `String` raw values when the enum needs display or serialization
- Computed properties for derived values are allowed (e.g. `seconds` on duration)
- Add a `static let `default`` property when a sensible default exists
- Response enums serve dual purpose: output from UseCases and input from Presentation (via Request fields) — both directions use `.toDomain` / `init(from:)` in `ResponseMapping.swift`
