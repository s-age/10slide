# Response Mapping Template

File: `Sources/UseCases/Responses/ResponseMapping.swift`

New mappings are added as extensions in the existing `ResponseMapping.swift`.

## Struct response — Entity to Response (`init(from:)`)

```swift
extension {{Name}}Response {
    init(from entity: {{DomainEntity}}) {
        self.init(
            id: entity.id,
            {{field1}}: entity.{{field1}},
            {{field2}}: {{ChildResponse}}(from: entity.{{field2}})
        )
    }
}
```

## Enum response — bidirectional mapping

```swift
extension {{Name}}Response {
    init(from entity: {{DomainEnum}}) {
        self = switch entity {
        case .{{case1}}: .{{case1}}
        case .{{case2}}: .{{case2}}
        }
    }

    var toDomain: {{DomainEnum}} {
        switch self {
        case .{{case1}}: .{{case1}}
        case .{{case2}}: .{{case2}}
        }
    }
}
```

## Composite response — with `toDomain` reverse mapping

```swift
extension {{Name}}Response {
    init(from entity: {{DomainEntity}}) {
        self.init(
            {{field1}}: {{ChildEnum}}Response(from: entity.{{field1}}),
            {{field2}}: {{ChildEnum2}}Response(from: entity.{{field2}}),
            {{field3}}: entity.{{field3}}
        )
    }

    var toDomain: {{DomainEntity}} {
        {{DomainEntity}}(
            {{field1}}: {{field1}}.toDomain,
            {{field2}}: {{field2}}.toDomain,
            {{field3}}: {{field3}}
        )
    }
}
```

## Rules

- `init(from:)` converts Domain Entity/Enum to Response (outbound)
- `.toDomain` converts Response back to Domain type (inbound — used by Requests carrying Response enums)
- All mappings live in `ResponseMapping.swift`, not in the Response definition file
- Child entities are mapped recursively: `ChildResponse(from: entity.child)`
- Enum mappings use `self = switch entity { ... }` syntax (Swift 5.9+)
