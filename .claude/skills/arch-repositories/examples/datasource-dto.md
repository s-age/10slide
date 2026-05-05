# Example: DataSource DTO Conversion Repository

A repository that converts between Infrastructure DTOs and Domain entities without any SwiftData dependency.

## Files to create

### 1. Protocol — `Sources/Repositories/Protocols/ConfigRepositoryProtocol.swift`

```swift
import Foundation

protocol ConfigRepositoryProtocol: Sendable {
    func load() async throws -> SlideshowConfig
    func save(_ config: SlideshowConfig) async throws
}
```

### 2. Implementation — `Sources/Repositories/Implementations/ConfigRepository.swift`

```swift
import Foundation

final class ConfigRepository: ConfigRepositoryProtocol {
    private let configDataSource: any ConfigDataSourceProtocol

    init(configDataSource: any ConfigDataSourceProtocol) {
        self.configDataSource = configDataSource
    }

    func load() async throws -> SlideshowConfig {
        guard let dto = try await configDataSource.load() else {
            return .default
        }
        return SlideshowConfig(
            duration: SlideDuration(rawValue: dto.duration) ?? .five,
            transition: TransitionType(rawValue: dto.transition) ?? .default,
            loop: dto.loop
        )
    }

    func save(_ config: SlideshowConfig) async throws {
        let dto = ConfigDTO(
            duration: config.duration.rawValue,
            transition: config.transition.rawValue,
            loop: config.loop
        )
        try await configDataSource.save(dto)
    }
}
```

### 3. DI wiring — add to `Sources/DI/RepositoryContainer.swift`

```swift
// Property declaration
let configRepository: any ConfigRepositoryProtocol

// In init(infrastructure:)
configRepository = ConfigRepository(configDataSource: infrastructure.configDataSource)
```

## Key points

- No `SwiftData` import — only `Foundation`
- DTO → Entity: reconstruct domain enums from raw value strings with fallback defaults
- Entity → DTO: extract raw values from domain enums into DTO fields
- Nil handling: return `.default` when DataSource returns no data
- DataSource protocol held as `any ConfigDataSourceProtocol` — never concrete
