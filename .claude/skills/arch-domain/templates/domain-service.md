# Domain Service Template

## Protocol

File: `Sources/Domain/Services/Protocols/{{Name}}DomainServiceProtocol.swift`

```swift
import Foundation

protocol {{Name}}DomainServiceProtocol: Sendable {
    func {{method1}}({{params}}) async throws -> {{ReturnType}}
    func {{method2}}({{params}}) async throws
}
```

## Implementation (repository-backed)

File: `Sources/Domain/Services/{{Name}}DomainService.swift`

```swift
import Foundation

final class {{Name}}DomainService: {{Name}}DomainServiceProtocol, Sendable {
    private let repository: any {{Repository}}RepositoryProtocol

    init(repository: any {{Repository}}RepositoryProtocol) {
        self.repository = repository
    }

    func {{method1}}({{params}}) async throws -> {{ReturnType}} {
        // Domain logic + repository dispatch
    }
}
```

## Implementation (pure computation)

File: `Sources/Domain/Services/{{Name}}DomainService.swift`

```swift
import Foundation

final class {{Name}}DomainService: {{Name}}DomainServiceProtocol, Sendable {
    func {{method1}}({{params}}) -> {{ReturnType}} {
        // Pure logic — no repository, no async
    }
}
```

## Rules

- Protocol: always `Sendable`, lives in `Protocols/` subdirectory
- Protocol: `import Foundation` only when using Foundation types in signatures
- Implementation: `final class`, conforms to protocol + `Sendable`
- Implementation: hold repositories as `any ProtocolName` — never concrete types
- Implementation: stateless or holds only `Sendable` protocol existentials
- Pure computation services: no `init` parameters, no `async`, no `throws`
- Never return Response types — return Domain Entities only
- Never import from UseCases or Presentation
- Never expose Repository protocols to callers
