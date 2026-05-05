# @Model Template

File: `Sources/Repositories/Models/{{Name}}Model.swift`

## Basic model

```swift
import SwiftData
import Foundation

@Model
final class {{Name}}Model {
    @Attribute(.unique) var id: UUID
    var {{field1}}: {{Type1}}
    var {{field2}}: {{Type2}}
    var {{optionalField}}: {{Type3}}?

    init(
        id: UUID = UUID(),
        {{field1}}: {{Type1}},
        {{field2}}: {{Type2}},
        {{optionalField}}: {{Type3}}? = nil
    ) {
        self.id = id
        self.{{field1}} = {{field1}}
        self.{{field2}} = {{field2}}
        self.{{optionalField}} = {{optionalField}}
    }
}
```

## Model with relationship

```swift
import SwiftData
import Foundation

@Model
final class {{Name}}Model {
    @Attribute(.unique) var id: UUID
    var {{field1}}: {{Type1}}
    @Relationship(deleteRule: .cascade, inverse: \{{Child}}Model.{{parent}}) var {{children}}: [{{Child}}Model]

    init(
        id: UUID = UUID(),
        {{field1}}: {{Type1}}
    ) {
        self.id = id
        self.{{field1}} = {{field1}}
        self.{{children}} = []
    }
}
```

## Model with enum raw values

```swift
@Model
final class {{Name}}Model {
    @Attribute(.unique) var id: UUID
    var {{enumField}}RawValue: String

    init(
        id: UUID = UUID(),
        {{enumField}}RawValue: String = "{{default}}"
    ) {
        self.id = id
        self.{{enumField}}RawValue = {{enumField}}RawValue
    }
}
```

## Rules

- Always `@Model final class` — never struct
- Always `@Attribute(.unique) var id: UUID` as first property
- Store enums as raw value strings (`{{name}}RawValue: String`)
- Relationships use `@Relationship` with explicit `deleteRule` and `inverse`
- Back-references are optional (`var parent: ParentModel?`)
- Import `SwiftData` and `Foundation` only
- Never add computed properties that reference domain types
- Never conform to `Sendable` — `@Model` types are actor-isolated
