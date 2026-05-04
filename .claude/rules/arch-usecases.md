---
paths:
  - 'Sources/UseCases/**/*.swift'
---

## Role

Provides a **stable, uniform API surface** for the Presentation layer. Use cases own all business logic and orchestration. ViewModels always call a use case — never a repository directly.

## Directory layout

```
UseCases/
├── Protocols/     # *UseCaseProtocol contracts consumed by Presentation
└── *.swift        # Concrete implementations
```

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation`, `Protocols/` (intra), `Domain/Entities` | `SwiftUI`, `UIKit`, `SwiftData`, `Photos` |
| `Repositories/Protocols/` | `Infrastructure` (concrete or protocol) |

## Patterns

**Thin use case — single repository delegation**

A use case that delegates directly to one repository is **not a smell** — it is load-bearing architecture. Callers always import from `UseCases/`. They never need to ask "should I call the repository directly or the use case?".

```swift
// Good — thin pass-through by design
protocol FetchSlidesUseCaseProtocol: Sendable {
    func execute() async throws -> [Slide]
}

final class FetchSlidesUseCase: FetchSlidesUseCaseProtocol {
    private let repository: any SlideRepositoryProtocol
    init(repository: any SlideRepositoryProtocol) { self.repository = repository }

    func execute() async throws -> [Slide] {
        try await repository.fetchAll()
    }
}

// Bad — ViewModel bypasses the use case layer because "it's just a pass-through"
// SomeViewModel.swift
let slides = try await slideRepository.fetchAll()   // NG: always go through a use case
```

**Use case with orchestration**

```swift
// Good — delegates entity construction to the domain factory; use case only orchestrates
final class CreateSlideshowUseCase: CreateSlideshowUseCaseProtocol {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    func execute(name: String, identifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        let slideshow = Slideshow.create(name: name, localIdentifiers: identifiers, config: config)
        try await slideshowRepository.save(slideshow)
        return slideshow
    }
}

// Bad — use case hard-codes entity construction rules (UUID assignment, ordering, defaults)
func execute(name: String, identifiers: [String]) async throws -> Slideshow {
    let slides = identifiers.enumerated().map { idx, id in
        Slide(id: UUID(), localIdentifier: id, order: idx, duration: 3.0, title: nil)   // NG: domain logic
    }
}
```

## Prohibitions

- Never import `SwiftUI`, `UIKit`, `SwiftData`, or `Photos` — enforced by SwiftLint
- Never inject concrete infrastructure or repository classes — inject protocols only
- Never hold `@Published` state or `@Observable` — that belongs in ViewModels
- Never annotate `@MainActor` — use cases are actor-agnostic
- Never add display logic (formatting, localized strings) — that belongs in Presentation
- Never define a protocol in the same file as its implementation — protocols live in `Protocols/`
