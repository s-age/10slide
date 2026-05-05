# Framework Adapter Template

File: `Sources/Infrastructure/{{Subdirectory}}/{{Name}}DataSource.swift`

For adapters wrapping system frameworks (Photos, CoreLocation, HealthKit, etc.).

```swift
import Foundation
import {{Framework}}

enum {{Name}}DataSourceError: Error {
    case notAuthorized
    case notFound
    case dataUnavailable
}

final class {{Name}}DataSource: {{Name}}DataSourceProtocol {
    func fetchAll{{Noun}}() async throws -> [{{PrimitiveType}}] {
        // 1. Request authorization if needed
        // 2. Fetch via framework API
        // 3. Map to primitive/DTO types
    }

    func fetch{{Noun}}({{param}}: {{ParamType}}) async throws -> {{DTOType}} {
        // 1. Fetch via framework API
        // 2. Wrap callback-based API with withCheckedThrowingContinuation
        // 3. Return DTO
    }

    func fetch{{Noun}}Thumbnail({{param}}: {{ParamType}}) async throws -> Data {
        // 1. Fetch raw data
        // 2. Offload conversion to Task.detached
        return try await Task.detached(priority: .userInitiated) {
            // Data format conversion (must meet all 3 guard conditions)
        }.value
    }
}
```

## Rules

- `final class` — not `@ModelActor` (no SwiftData)
- Error enum: local to the file, not in `Errors/` (adapter-specific)
- Authorization: use `request*` APIs, not `status` APIs
- Continuations: ensure exactly one `resume` per `withCheckedThrowingContinuation`
- Data format conversion: only if it uses Infra-only frameworks, returns `Data`/DTO, has no business logic
- `Task.detached` for blocking work — never block the cooperative pool
