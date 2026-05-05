# Example: Domain Service (Simple Delegation)

A service that delegates to a Repository with minimal orchestration logic.

## Files to create

### 1. Protocol — `Sources/Domain/Services/Protocols/ConfigDomainServiceProtocol.swift`

```swift
protocol ConfigDomainServiceProtocol: Sendable {
    func load() async throws -> SlideshowConfig
    func save(_ config: SlideshowConfig) async throws
}
```

### 2. Implementation — `Sources/Domain/Services/ConfigDomainService.swift`

```swift
import Foundation

final class ConfigDomainService: ConfigDomainServiceProtocol, Sendable {
    private let repository: any ConfigRepositoryProtocol

    init(repository: any ConfigRepositoryProtocol) {
        self.repository = repository
    }

    func load() async throws -> SlideshowConfig {
        try await repository.load()
    }

    func save(_ config: SlideshowConfig) async throws {
        try await repository.save(config)
    }
}
```

### 3. DI wiring — add to `Sources/DI/DomainContainer.swift`

```swift
// Property declaration
let configService: any ConfigDomainServiceProtocol

// In init(repositories:)
configService = ConfigDomainService(repository: repositories.configRepository)
```

## When to use this pattern

- The domain operation is a straightforward pass-through to a single repository method
- No entity construction, mutation, or cross-repository coordination is needed
- The service still exists to maintain the layer boundary (UseCases never call Repositories directly)

## Key points

- Even trivial delegation justifies a service — it preserves the architectural contract
- Protocol may omit `import Foundation` when signatures use only Domain types
- Future domain logic (caching, validation, defaults) can be added here without changing callers
