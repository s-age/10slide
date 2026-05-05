# DataSource Repository Template

File: `Sources/Repositories/Implementations/{{Name}}Repository.swift`

## DTO conversion variant

```swift
import Foundation

final class {{Name}}Repository: {{Name}}RepositoryProtocol {
    private let {{camelCase}}DataSource: any {{Name}}DataSourceProtocol

    init({{camelCase}}DataSource: any {{Name}}DataSourceProtocol) {
        self.{{camelCase}}DataSource = {{camelCase}}DataSource
    }

    func load() async throws -> {{Entity}} {
        guard let dto = try await {{camelCase}}DataSource.load() else {
            return .default
        }
        return {{Entity}}(
            {{field1}}: {{DomainType1}}(rawValue: dto.{{field1}}) ?? .{{fallback1}},
            {{field2}}: {{DomainType2}}(rawValue: dto.{{field2}}) ?? .{{fallback2}}
        )
    }

    func save(_ {{entity}}: {{Entity}}) async throws {
        let dto = {{Name}}DTO(
            {{field1}}: {{entity}}.{{field1}}.rawValue,
            {{field2}}: {{entity}}.{{field2}}.rawValue
        )
        try await {{camelCase}}DataSource.save(dto)
    }
}
```

## Delegation variant

```swift
import Foundation

final class {{Name}}Repository: {{Name}}RepositoryProtocol {
    private let {{camelCase}}DataSource: any {{Name}}DataSourceProtocol

    init({{camelCase}}DataSource: any {{Name}}DataSourceProtocol) {
        self.{{camelCase}}DataSource = {{camelCase}}DataSource
    }

    func fetchAll{{Noun}}() async throws -> [{{PrimitiveType}}] {
        try await {{camelCase}}DataSource.fetchAll{{Noun}}()
    }

    func fetch{{Noun}}({{param}}: {{ParamType}}) async throws -> {{ReturnType}} {
        let dto = try await {{camelCase}}DataSource.fetch{{Noun}}({{param}}: {{param}})
        return dto.{{extractedField}}
    }

    var {{computedProperty}}: {{Type}} {
        {{camelCase}}DataSource.{{computedProperty}}
    }
}
```

## Rules

- Never import `SwiftData` — DataSource repositories have no @Model dependency
- `import Foundation` only
- Hold DataSource protocols as `any ProtocolName` — never concrete types
- DTO conversion: map DTO fields → domain enum/struct constructors with fallback defaults
- Delegation: pass-through when no conversion needed; extract DTO fields when minimal
- Computed properties may delegate synchronously when the backing source is non-async
