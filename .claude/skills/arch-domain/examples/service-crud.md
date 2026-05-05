# Example: Domain Service (CRUD with Repository)

A service that orchestrates entity lifecycle operations through a Repository protocol.

## Files to create

### 1. Protocol — `Sources/Domain/Services/Protocols/SlideshowDomainServiceProtocol.swift`

```swift
import Foundation

protocol SlideshowDomainServiceProtocol: Sendable {
    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow
    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow
    func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow
    func delete(id: UUID) async throws
    func fetch(id: UUID) async throws -> Slideshow?
    func fetchAll() async throws -> [Slideshow]
}
```

### 2. Implementation — `Sources/Domain/Services/SlideshowDomainService.swift`

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

    func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.applying(config: config)
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

### 3. DI wiring — add to `Sources/DI/DomainContainer.swift`

```swift
// Property declaration
let slideshowService: any SlideshowDomainServiceProtocol

// In init(repositories:)
slideshowService = SlideshowDomainService(repository: repositories.slideshowRepository)
```

## Key points

- Fetch-then-mutate pattern: `guard let existing = try await repository.fetch(id:)` → throw if not found
- Entity factory: delegates construction to `Slideshow.create(...)` — service doesn't manually build entities
- Entity update: uses immutable update methods (`updating(...)`, `applying(...)`)
- Error throwing: uses `DomainError` from `Sources/Errors/`
- Repository protocol: held as `any SlideshowRepositoryProtocol` — never the concrete type
