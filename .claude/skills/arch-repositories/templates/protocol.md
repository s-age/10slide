# Repository Protocol Template

File: `Sources/Repositories/Protocols/{{Name}}RepositoryProtocol.swift`

## CRUD protocol

```swift
import Foundation

protocol {{Name}}RepositoryProtocol: Sendable {
    func fetchAll() async throws -> [{{Entity}}]
    func fetch(id: UUID) async throws -> {{Entity}}?
    func save(_ {{entity}}: {{Entity}}) async throws
    func delete(id: UUID) async throws
}
```

## Load/save protocol (config-style)

```swift
import Foundation

protocol {{Name}}RepositoryProtocol: Sendable {
    func load() async throws -> {{Entity}}
    func save(_ {{entity}}: {{Entity}}) async throws
}
```

## Read-only protocol (data source access)

```swift
import Foundation

protocol {{Name}}RepositoryProtocol: Sendable {
    func fetchAll{{Noun}}() async throws -> [{{PrimitiveType}}]
    func fetch{{Noun}}({{param}}: {{ParamType}}) async throws -> {{ReturnType}}
    var {{computedProperty}}: {{Type}} { get }
}
```

## Rules

- Always conform to `Sendable`
- Always live in `Protocols/` subdirectory — never in the implementation file
- Return domain entities or Foundation primitives only — never `@Model` types or DTOs
- `import Foundation` only when using Foundation types (`UUID`, `Date`, `URL`, `Data`, `TimeInterval`)
- Methods are `async throws` unless synchronous access is guaranteed
- Computed properties may be synchronous when the backing source is non-async
