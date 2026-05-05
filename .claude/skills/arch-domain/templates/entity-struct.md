# Entity Struct Template

File: `Sources/Domain/Entities/{{Name}}.swift`

## Basic entity

```swift
import Foundation

struct {{Name}}: Identifiable, Equatable, Sendable {
    let id: UUID
    let {{field1}}: {{Type1}}
    var {{field2}}: {{Type2}}
    var {{optionalField}}: {{Type3}}?
}
```

## Entity with factory method

```swift
import Foundation

struct {{Name}}: Identifiable, Equatable, Sendable {
    let id: UUID
    let {{field1}}: {{Type1}}
    var {{field2}}: {{Type2}}
    var createdAt: Date

    static func create({{params}}) -> {{Name}} {
        {{Name}}(
            id: UUID(),
            {{field1}}: {{value1}},
            {{field2}}: {{value2}},
            createdAt: Date()
        )
    }
}
```

## Entity with immutable update methods

```swift
func applying({{param}}: {{Type}}) -> {{Name}} {
    var updated = self
    updated.{{field}} = {{param}}
    return updated
}

func updating({{params}}) -> {{Name}} {
    var updated = self
    updated.{{field1}} = {{value1}}
    updated.{{field2}} = {{value2}}
    return updated
}
```

## Rules

- Always conform to `Identifiable`, `Equatable`, `Sendable`
- `let id: UUID` as the first field
- Use `let` for immutable identity fields, `var` for mutable state
- Use `?` only when a value is legitimately absent at the domain level
- `import Foundation` only when using Foundation types
- Factory methods are `static func create(...)` — encapsulate construction rules
- Update methods return a new copy — never mutate in place externally
- Private helpers (e.g. `makeSlides`) are `private static func`
