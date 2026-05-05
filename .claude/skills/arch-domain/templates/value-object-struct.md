# Value Object Struct Template

File: `Sources/Domain/Entities/{{Name}}.swift`

## Basic value object

```swift
import Foundation

struct {{Name}}: Equatable, Sendable, Codable {
    var {{field1}}: {{Type1}}
    var {{field2}}: {{Type2}}
    var {{field3}}: {{Type3}}

    static let `default` = {{Name}}(
        {{field1}}: {{defaultValue1}},
        {{field2}}: {{defaultValue2}},
        {{field3}}: {{defaultValue3}}
    )
}
```

## Rules

- Conform to `Equatable`, `Sendable` — add `Codable` when serialized
- No `id: UUID` — value objects have no unique identity
- Provide `static let default` when a sensible default exists
- Use `var` for all fields — value objects are often mutated as part of an owning entity
- `import Foundation` only when using Foundation types
- No `Identifiable` — that distinguishes entities from value objects
