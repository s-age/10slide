# UseCases Layer (refactored)

All UseCases are refactored to:
1. Accept a `UseCaseRequest`-conforming struct
2. Call `request.validate()` before processing
3. Delegate to a Domain Service (never directly to a Repository)
4. Return a Response type (never a Domain Entity)

---

## Protocol pattern (updated)

All UseCase protocols follow this uniform shape:

```swift
protocol <Name>UseCaseProtocol: Sendable {
    func execute(_ request: <Name>Request) async throws -> <ReturnType>
}
```

For void-returning UseCases, the return type is omitted (throws only).

---

## `Sources/UseCases/Protocols/CreateSlideshowUseCaseProtocol.swift` (modified)

```swift
protocol CreateSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse
}
```

## `Sources/UseCases/CreateSlideshowUseCase.swift` (modified)

```swift
import Foundation

final class CreateSlideshowUseCase: CreateSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        try request.validate()
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        let slideshow = try await domainService.create(
            name: request.name,
            localIdentifiers: request.localIdentifiers,
            config: config
        )
        return SlideshowResponse(from: slideshow)
    }
}
```

---

## `Sources/UseCases/Protocols/UpdateSlideshowUseCaseProtocol.swift` (modified)

```swift
import Foundation

protocol UpdateSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: UpdateSlideshowRequest) async throws -> SlideshowResponse
}
```

## `Sources/UseCases/UpdateSlideshowUseCase.swift` (modified)

```swift
import Foundation

final class UpdateSlideshowUseCase: UpdateSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: UpdateSlideshowRequest) async throws -> SlideshowResponse {
        try request.validate()
        let slideshow = try await domainService.update(
            id: request.id,
            name: request.name,
            localIdentifiers: request.localIdentifiers
        )
        return SlideshowResponse(from: slideshow)
    }
}
```

---

## `Sources/UseCases/Protocols/DeleteSlideshowUseCaseProtocol.swift` (modified)

```swift
import Foundation

protocol DeleteSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: DeleteSlideshowRequest) async throws
}
```

## `Sources/UseCases/DeleteSlideshowUseCase.swift` (modified)

```swift
import Foundation

final class DeleteSlideshowUseCase: DeleteSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: DeleteSlideshowRequest) async throws {
        try request.validate()
        try await domainService.delete(id: request.id)
    }
}
```

---

## `Sources/UseCases/Protocols/FetchSlideshowUseCaseProtocol.swift` (modified)

```swift
import Foundation

protocol FetchSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: FetchSlideshowRequest) async throws -> SlideshowResponse?
}
```

## `Sources/UseCases/FetchSlideshowUseCase.swift` (modified)

```swift
import Foundation

final class FetchSlideshowUseCase: FetchSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchSlideshowRequest) async throws -> SlideshowResponse? {
        try request.validate()
        guard let slideshow = try await domainService.fetch(id: request.id) else { return nil }
        return SlideshowResponse(from: slideshow)
    }
}
```

---

## `Sources/UseCases/Protocols/FetchSlideshowsUseCaseProtocol.swift` (modified)

```swift
protocol FetchSlideshowsUseCaseProtocol: Sendable {
    func execute(_ request: FetchSlideshowsRequest) async throws -> [SlideshowResponse]
}
```

## `Sources/UseCases/FetchSlideshowsUseCase.swift` (modified)

```swift
final class FetchSlideshowsUseCase: FetchSlideshowsUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchSlideshowsRequest) async throws -> [SlideshowResponse] {
        try request.validate()
        let slideshows = try await domainService.fetchAll()
        return slideshows.map { SlideshowResponse(from: $0) }
    }
}
```

---

## `Sources/UseCases/Protocols/FetchLibraryUseCaseProtocol.swift` (modified)

```swift
protocol FetchLibraryUseCaseProtocol: Sendable {
    func execute(_ request: FetchLibraryRequest) async throws -> [String]
}
```

## `Sources/UseCases/FetchLibraryUseCase.swift` (modified)

```swift
import Foundation

final class FetchLibraryUseCase: FetchLibraryUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchLibraryRequest) async throws -> [String] {
        try request.validate()
        return try await domainService.fetchAllIdentifiers()
    }
}
```

---

## `Sources/UseCases/Protocols/LoadSlideImageUseCaseProtocol.swift` (modified)

```swift
protocol LoadSlideImageUseCaseProtocol: Sendable {
    func execute(_ request: LoadSlideImageRequest) async throws -> Data
}
```

## `Sources/UseCases/LoadSlideImageUseCase.swift` (modified)

```swift
import Foundation

final class LoadSlideImageUseCase: LoadSlideImageUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadSlideImageRequest) async throws -> Data {
        try request.validate()
        return try await domainService.fetchImageData(localIdentifier: request.localIdentifier)
    }
}
```

---

## `Sources/UseCases/Protocols/LoadThumbnailUseCaseProtocol.swift` (modified)

```swift
protocol LoadThumbnailUseCaseProtocol: Sendable {
    func execute(_ request: LoadThumbnailRequest) async throws -> Data
}
```

## `Sources/UseCases/LoadThumbnailUseCase.swift` (modified)

```swift
import Foundation

final class LoadThumbnailUseCase: LoadThumbnailUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadThumbnailRequest) async throws -> Data {
        try request.validate()
        return try await domainService.fetchThumbnailData(localIdentifier: request.localIdentifier)
    }
}
```

---

## `Sources/UseCases/Protocols/LoadConfigUseCaseProtocol.swift` (modified)

```swift
protocol LoadConfigUseCaseProtocol: Sendable {
    func execute(_ request: LoadConfigRequest) async throws -> SlideshowConfigResponse
}
```

## `Sources/UseCases/LoadConfigUseCase.swift` (modified)

```swift
import Foundation

final class LoadConfigUseCase: LoadConfigUseCaseProtocol, Sendable {
    private let domainService: any ConfigDomainServiceProtocol

    init(domainService: any ConfigDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadConfigRequest) async throws -> SlideshowConfigResponse {
        try request.validate()
        let config = try await domainService.load()
        return SlideshowConfigResponse(from: config)
    }
}
```

---

## `Sources/UseCases/Protocols/SaveConfigUseCaseProtocol.swift` (modified)

```swift
protocol SaveConfigUseCaseProtocol: Sendable {
    func execute(_ request: SaveConfigRequest) async throws
}
```

## `Sources/UseCases/SaveConfigUseCase.swift` (modified)

```swift
import Foundation

final class SaveConfigUseCase: SaveConfigUseCaseProtocol, Sendable {
    private let domainService: any ConfigDomainServiceProtocol

    init(domainService: any ConfigDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: SaveConfigRequest) async throws {
        try request.validate()
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        try await domainService.save(config)
    }
}
```

---

## `Sources/UseCases/Protocols/AdvanceSlideUseCaseProtocol.swift` (modified)

```swift
protocol AdvanceSlideUseCaseProtocol: Sendable {
    func execute(_ request: AdvanceSlideRequest) throws -> Int?
    func executePrevious(_ request: PreviousSlideRequest) throws -> Int?
}
```

## `Sources/UseCases/AdvanceSlideUseCase.swift` (modified)

```swift
final class AdvanceSlideUseCase: AdvanceSlideUseCaseProtocol, Sendable {
    private let domainService: any PlaybackDomainServiceProtocol

    init(domainService: any PlaybackDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        try request.validate()
        return domainService.nextIndex(
            totalSlides: request.totalSlides,
            currentIndex: request.currentIndex,
            loop: request.loop
        )
    }

    func executePrevious(_ request: PreviousSlideRequest) throws -> Int? {
        try request.validate()
        return domainService.previousIndex(
            totalSlides: request.totalSlides,
            currentIndex: request.currentIndex,
            loop: request.loop
        )
    }
}
```

---

## `Sources/UseCases/Protocols/UpdateSlideshowConfigUseCaseProtocol.swift` (modified)

```swift
import Foundation

protocol UpdateSlideshowConfigUseCaseProtocol: Sendable {
    func execute(_ request: UpdateSlideshowConfigRequest) async throws -> SlideshowResponse
}
```

## `Sources/UseCases/UpdateSlideshowConfigUseCase.swift` (modified)

```swift
import Foundation

final class UpdateSlideshowConfigUseCase: UpdateSlideshowConfigUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol
    private let playbackService: any PlaybackDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol, playbackService: any PlaybackDomainServiceProtocol) {
        self.domainService = domainService
        self.playbackService = playbackService
    }

    func execute(_ request: UpdateSlideshowConfigRequest) async throws -> SlideshowResponse {
        try request.validate()
        guard let slideshow = try await domainService.fetch(id: request.slideshowID) else {
            throw DomainError.slideshowNotFound(request.slideshowID)
        }
        let newConfig = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        let updated = playbackService.applyConfig(newConfig, to: slideshow)
        return SlideshowResponse(from: updated)
    }
}
```

---

## `Sources/UseCases/Protocols/SetDirectoryUseCaseProtocol.swift` (modified)

```swift
import Foundation

protocol SetDirectoryUseCaseProtocol: Sendable {
    func execute(_ request: SetDirectoryRequest) async throws
}
```

## `Sources/UseCases/SetDirectoryUseCase.swift` (modified)

```swift
import Foundation

final class SetDirectoryUseCase: SetDirectoryUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: SetDirectoryRequest) async throws {
        try request.validate()
        await domainService.setDirectory(request.url)
    }
}
```

---

## `Sources/UseCases/Protocols/AddDroppedFilesUseCaseProtocol.swift` (modified)

```swift
import Foundation

protocol AddDroppedFilesUseCaseProtocol: Sendable {
    func execute(_ request: AddDroppedFilesRequest) throws -> [String]
}
```

## `Sources/UseCases/AddDroppedFilesUseCase.swift` (modified)

```swift
import Foundation

final class AddDroppedFilesUseCase: AddDroppedFilesUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AddDroppedFilesRequest) throws -> [String] {
        try request.validate()
        return domainService.filterDroppedFiles(
            urls: request.urls,
            existingIdentifiers: request.existingIdentifiers
        )
    }
}
```
