# Repositories Layer

## `Sources/Repositories/Protocols/ConfigRepositoryProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol ConfigRepositoryProtocol: Sendable {
    func load() async throws -> SlideshowConfig
    func save(_ config: SlideshowConfig) async throws
}
```

## `Sources/Repositories/Protocols/SlideshowRepositoryProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol SlideshowRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slideshow]
    func fetch(id: UUID) async throws -> Slideshow?
    func save(_ slideshow: Slideshow) async throws
    func delete(id: UUID) async throws
}
```

## `Sources/Repositories/Protocols/ImageRepositoryProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol ImageRepositoryProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImageData(localIdentifier: String) async throws -> Data
}
```

## `Sources/Repositories/Implementations/ConfigRepository.swift` (new)

**Implements**: ConfigRepositoryProtocol

```swift
import Foundation

final class ConfigRepository: ConfigRepositoryProtocol {
    private let configDataSource: any ConfigDataSourceProtocol

    init(configDataSource: any ConfigDataSourceProtocol) {
        self.configDataSource = configDataSource
    }

    func load() async throws -> SlideshowConfig {
        let dto = try await configDataSource.load()
        return SlideshowConfig(
            defaultDuration: dto.defaultDuration,
            transition: TransitionType(rawValue: dto.transition) ?? .fade,
            loop: dto.loop
        )
    }

    func save(_ config: SlideshowConfig) async throws {
        let dto = ConfigDTO(
            defaultDuration: config.defaultDuration,
            transition: config.transition.rawValue,
            loop: config.loop
        )
        try await configDataSource.save(dto)
    }
}
```

## `Sources/Repositories/Implementations/SlideshowRepository.swift` (new)

**Implements**: SlideshowRepositoryProtocol

```swift
import Foundation

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let slideshowDataSource: any SlideshowDataSourceProtocol
    private let slideDataSource: any SlideDataSourceProtocol

    init(
        slideshowDataSource: any SlideshowDataSourceProtocol,
        slideDataSource: any SlideDataSourceProtocol
    ) {
        self.slideshowDataSource = slideshowDataSource
        self.slideDataSource = slideDataSource
    }

    func fetchAll() async throws -> [Slideshow] { ... }
    func fetch(id: UUID) async throws -> Slideshow? { ... }
    func save(_ slideshow: Slideshow) async throws { ... }
    func delete(id: UUID) async throws { ... }
}
```

## `Sources/Repositories/Implementations/ImageRepository.swift` (new)

**Implements**: ImageRepositoryProtocol

```swift
import Foundation

final class ImageRepository: ImageRepositoryProtocol {
    private let imageDataSource: any ImageDataSourceProtocol

    init(imageDataSource: any ImageDataSourceProtocol) {
        self.imageDataSource = imageDataSource
    }

    func fetchAllIdentifiers() async throws -> [String] {
        try await imageDataSource.fetchAllIdentifiers()
    }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        let dto = try await imageDataSource.fetchImage(localIdentifier: localIdentifier)
        return dto.data
    }
}
```
