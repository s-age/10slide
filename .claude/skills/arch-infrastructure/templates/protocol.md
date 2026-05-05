# Protocol Template

File: `Sources/Infrastructure/Protocols/{{Name}}DataSourceProtocol.swift`

```swift
import Foundation

protocol {{Name}}DataSourceProtocol: Sendable {
    func fetch{{Noun}}({{param}}: {{ParamType}}) async throws -> {{ReturnType}}
}
```

## With default implementations for optional methods

```swift
import Foundation

protocol {{Name}}DataSourceProtocol: Sendable {
    func fetch{{Noun}}({{param}}: {{ParamType}}) async throws -> {{ReturnType}}
    func {{optionalMethod}}(_ {{arg}}: {{ArgType}})
    var {{optionalProperty}}: {{Type}} { get }
}

extension {{Name}}DataSourceProtocol {
    func {{optionalMethod}}(_ {{arg}}: {{ArgType}}) {}
    var {{optionalProperty}}: {{Type}} { {{defaultValue}} }
}
```

## Rules

- `import Foundation` only — never framework imports in protocol files
- Always declare `Sendable`
- Return DTOs or primitive types — never domain entities
- Use `async throws` for all I/O methods
- Default implementations for methods specific to one conformer
