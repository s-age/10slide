# UseCases Layer

## `Sources/UseCases/CreateSlideshowUseCase.swift` (new)

```swift
import Foundation

final class CreateSlideshowUseCase: Sendable {
    private let slideshowRepository: any SlideshowRepositoryProtocol
    private let configRepository: any ConfigRepositoryProtocol

    init(
        slideshowRepository: any SlideshowRepositoryProtocol,
        configRepository: any ConfigRepositoryProtocol
    ) {
        self.slideshowRepository = slideshowRepository
        self.configRepository = configRepository
    }

    func execute(name: String, localIdentifiers: [String]) async throws -> Slideshow {
        let config = try await configRepository.load()
        let slides = localIdentifiers.enumerated().map { index, id in
            Slide(
                id: UUID(),
                localIdentifier: id,
                order: index,
                duration: config.defaultDuration,
                title: nil
            )
        }
        let slideshow = Slideshow(
            id: UUID(),
            name: name,
            slides: slides,
            config: config,
            createdAt: Date()
        )
        try await slideshowRepository.save(slideshow)
        return slideshow
    }
}
```

## `Sources/UseCases/FetchSlideshowUseCase.swift` (new)

```swift
import Foundation

final class FetchSlideshowUseCase: Sendable {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(id: UUID) async throws -> Slideshow? {
        try await slideshowRepository.fetch(id: id)
    }
}
```

## `Sources/UseCases/FetchLibraryUseCase.swift` (new)

```swift
import Foundation

final class FetchLibraryUseCase: Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute() async throws -> [String] {
        try await imageRepository.fetchAllIdentifiers()
    }
}
```

## `Sources/UseCases/LoadSlideImageUseCase.swift` (new)

```swift
import Foundation

final class LoadSlideImageUseCase: Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute(localIdentifier: String) async throws -> Data {
        try await imageRepository.fetchImageData(localIdentifier: localIdentifier)
    }
}
```

## `Sources/UseCases/LoadConfigUseCase.swift` (new)

```swift
import Foundation

final class LoadConfigUseCase: Sendable {
    private let configRepository: any ConfigRepositoryProtocol

    init(configRepository: any ConfigRepositoryProtocol) {
        self.configRepository = configRepository
    }

    func execute() async throws -> SlideshowConfig {
        try await configRepository.load()
    }
}
```

## `Sources/UseCases/SaveConfigUseCase.swift` (new)

```swift
import Foundation

final class SaveConfigUseCase: Sendable {
    private let configRepository: any ConfigRepositoryProtocol

    init(configRepository: any ConfigRepositoryProtocol) {
        self.configRepository = configRepository
    }

    func execute(_ config: SlideshowConfig) async throws {
        try await configRepository.save(config)
    }
}
```
