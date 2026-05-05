# Request Template

File: `Sources/UseCases/Requests/{{Name}}Request.swift`

## With validation

```swift
import Foundation

struct {{Name}}Request: UseCaseRequest {
    let {{field1}}: {{Type1}}
    let {{field2}}: {{Type2}}

    func validate() throws {
        guard {{validationCondition}} else {
            throw ValidationError.{{errorCase}}
        }
    }
}
```

## Without validation (empty body)

```swift
struct {{Name}}Request: UseCaseRequest {
    let {{field1}}: {{Type1}}

    func validate() throws {}
}
```

## Parameterless (trigger-only)

```swift
struct {{Name}}Request: UseCaseRequest {
    func validate() throws {}
}
```

## Rules

- Conform to `UseCaseRequest` (which extends `Sendable`)
- Always implement `validate() throws` even if the body is empty
- Use `let` for all fields — requests are immutable value types
- Throw `ValidationError` cases (defined in `Sources/Errors/`)
- Response enums (`SlideDurationResponse`, `TransitionTypeResponse`) may appear as fields when the Presentation layer provides enum selections — these carry `.toDomain` converters
- `import Foundation` only when using `UUID`, `URL`, `Date`, or `Data`
