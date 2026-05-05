# Domain/Services Layer

New layer: `Sources/Domain/Services/`

**Import allowlist**: `Foundation`, `Domain/Entities`, `Repositories/Protocols`

Domain Services orchestrate Repository calls and Entity logic. They are the sole consumers of Repository protocols.

---

## `Sources/Domain/Services/Protocols/SlideshowDomainServiceProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol SlideshowDomainServiceProtocol: Sendable {
    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow
    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow
    func delete(id: UUID) async throws
    func fetch(id: UUID) async throws -> Slideshow?
    func fetchAll() async throws -> [Slideshow]
}
```

## `Sources/Domain/Services/SlideshowDomainService.swift` (new)

**Implements**: SlideshowDomainServiceProtocol

```swift
import Foundation

final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    private let repository: any SlideshowRepositoryProtocol

    init(repository: any SlideshowRepositoryProtocol) {
        self.repository = repository
    }

    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        let slideshow = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
        try await repository.save(slideshow)
        return slideshow
    }

    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
        try await repository.save(updated)
        return updated
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await repository.fetch(id: id)
    }

    func fetchAll() async throws -> [Slideshow] {
        try await repository.fetchAll()
    }
}
```

---

## `Sources/Domain/Services/Protocols/ImageDomainServiceProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol ImageDomainServiceProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImageData(localIdentifier: String) async throws -> Data
    func fetchThumbnailData(localIdentifier: String) async throws -> Data
    func setDirectory(_ url: URL) async
    func filterDroppedFiles(urls: [URL], existingIdentifiers: [String]) -> [String]
}
```

## `Sources/Domain/Services/ImageDomainService.swift` (new)

**Implements**: ImageDomainServiceProtocol

```swift
import Foundation

final class ImageDomainService: ImageDomainServiceProtocol, Sendable {
    private let repository: any ImageRepositoryProtocol

    init(repository: any ImageRepositoryProtocol) {
        self.repository = repository
    }

    func fetchAllIdentifiers() async throws -> [String] {
        try await repository.fetchAllIdentifiers()
    }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        try await repository.fetchImageData(localIdentifier: localIdentifier)
    }

    func fetchThumbnailData(localIdentifier: String) async throws -> Data {
        try await repository.fetchThumbnailData(localIdentifier: localIdentifier)
    }

    func setDirectory(_ url: URL) async {
        await repository.setDirectory(url)
    }

    func filterDroppedFiles(urls: [URL], existingIdentifiers: [String]) -> [String] {
        let supported = repository.supportedExtensions
        let existing = Set(existingIdentifiers)
        return urls
            .filter { supported.contains($0.pathExtension.lowercased()) }
            .map { $0.path }
            .filter { !existing.contains($0) }
    }
}
```

---

## `Sources/Domain/Services/Protocols/ConfigDomainServiceProtocol.swift` (new)

**Protocol**:
```swift
protocol ConfigDomainServiceProtocol: Sendable {
    func load() async throws -> SlideshowConfig
    func save(_ config: SlideshowConfig) async throws
}
```

## `Sources/Domain/Services/ConfigDomainService.swift` (new)

**Implements**: ConfigDomainServiceProtocol

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

---

## `Sources/Domain/Services/Protocols/PlaybackDomainServiceProtocol.swift` (new)

**Protocol**:
```swift
protocol PlaybackDomainServiceProtocol: Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int?
    func previousIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int?
    func applyConfig(_ config: SlideshowConfig, to slideshow: Slideshow) -> Slideshow
}
```

## `Sources/Domain/Services/PlaybackDomainService.swift` (new)

**Implements**: PlaybackDomainServiceProtocol

```swift
import Foundation

final class PlaybackDomainService: PlaybackDomainServiceProtocol, Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex < totalSlides - 1 { return currentIndex + 1 }
        return loop ? 0 : nil
    }

    func previousIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex > 0 { return currentIndex - 1 }
        return loop ? totalSlides - 1 : nil
    }

    func applyConfig(_ config: SlideshowConfig, to slideshow: Slideshow) -> Slideshow {
        slideshow.applying(config: config)
    }
}
```

---

## `Sources/Domain/Services/DomainError.swift` (new)

```swift
import Foundation

enum DomainError: Error, Sendable {
    case slideshowNotFound(UUID)
}
```
