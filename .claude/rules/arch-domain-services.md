---
paths:
  - 'Sources/Domain/Services/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/Domain/Services/`:

- **Layer responsibility**: Orchestrates Repository calls and Entity logic. The sole consumer of Repository protocols in the architecture. Called by UseCases only.
- **Import allowlist**: `Foundation`, `Domain/Entities`, `Repositories/Protocols`, `Errors` — never `SwiftData`, `Photos`, `SwiftUI`, `UIKit`, `Infrastructure`, `UseCases`.

## Directory layout

```
Domain/Services/
├── Protocols/   # *DomainServiceProtocol contracts consumed by UseCases
└── *.swift      # Concrete implementations
```

## Patterns

**Service — `final class` conforming to protocol + `Sendable`**

```swift
// Good — stateless or holds only Sendable protocol existentials
final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    private let repository: any SlideshowRepositoryProtocol

    init(repository: any SlideshowRepositoryProtocol) {
        self.repository = repository
    }
}
```

**Entity creation + persistence in one operation**

```swift
// Good — Domain Service owns entity creation rules and Repository dispatch
func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
    let entity = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
    try await repository.save(entity)
    return entity
}
```

**Pure computation services**

```swift
// Good — no Repository dependency; pure logic extracted from Entity
final class PlaybackDomainService: PlaybackDomainServiceProtocol, Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex < totalSlides - 1 { return currentIndex + 1 }
        return loop ? 0 : nil
    }
}
```

## Prohibitions

- Never import `SwiftData`, `Photos`, `SwiftUI`, or `UIKit` — enforced by SwiftLint
- Never import from `UseCases` — dependency flows upward only
- Never import `Infrastructure` concrete types — use Repository protocols only
- Never expose Repository protocols to callers — callers see only DomainServiceProtocol
- Never place protocols in implementation files — protocols live in `Protocols/`
- Never add display logic (formatting, localized strings) — that belongs in Presentation
- Never return Response types — Domain Services return Domain Entities; mapping is UseCase's job
