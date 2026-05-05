# Response Struct Template

File: `Sources/UseCases/Responses/{{Name}}Response.swift`

```swift
import Foundation

struct {{Name}}Response: Identifiable, Equatable, Sendable {
    let id: UUID
    let {{field1}}: {{Type1}}
    let {{field2}}: {{Type2}}
}
```

## Rules

- Conform to `Sendable` always
- Add `Identifiable` when the response represents a distinct entity
- Add `Equatable` for diffing in SwiftUI lists and state comparison
- Use `let` for all fields — responses are immutable
- `import Foundation` when using `UUID`, `Date`, `Data`, or `URL`
- Never include Domain entity types — only primitives, other Response types, or Foundation types
- Child responses (e.g. `[SlideResponse]`) are referenced by their Response type, never by Domain entity
