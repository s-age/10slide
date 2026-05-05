# DTO Template

File: `Sources/Infrastructure/{{Subdirectory}}/DTO/{{Name}}DTO.swift`

## Standard DTO

```swift
import Foundation

struct {{Name}}DTO: Sendable {
    let {{field1}}: {{PrimitiveType1}}
    let {{field2}}: {{PrimitiveType2}}
}
```

## Codable DTO (for file serialization)

```swift
import Foundation

struct {{Name}}DTO: Sendable, Codable {
    var {{field1}}: {{PrimitiveType1}}
    var {{field2}}: {{PrimitiveType2}}
}
```

## Rules

- `import Foundation` only
- Always `Sendable`
- Add `Codable` only when serialized/deserialized (YAML, JSON, plist)
- Use `let` for immutable transport; `var` for round-trip serialization
- Primitive types only (`String`, `Data`, `Date`, `Bool`, `Int`, `Double`)
- Never use domain enums or entity types
