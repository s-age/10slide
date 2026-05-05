---
paths:
  - 'Sources/UseCases/**/*.swift'
---

## Role

Provides a **stable, uniform API surface** for the Presentation layer. UseCases accept Request structs, delegate to Domain Services, and return Response types. They never touch Repositories directly.

## Directory layout

```
UseCases/
├── Protocols/     # *UseCaseProtocol contracts consumed by Presentation
├── Requests/      # UseCaseRequest protocol + concrete Request structs
├── Responses/     # Response structs + Response enums + mapping extensions
└── *.swift        # Concrete implementations
```

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation` | `SwiftUI`, `UIKit`, `SwiftData`, `Photos` |
| `Domain/Entities` (for Entity → Response mapping) | `Repositories/Protocols` (route through Domain Services) |
| `Domain/Services/Protocols/` | `Infrastructure` (concrete or protocol) |
| `Requests/`, `Responses/` (intra-layer) | |

## Request/Response pattern

Every UseCase follows this uniform shape:

```swift
// Protocol
protocol CreateSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse
}

// Implementation
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

Key rules:
1. Always call `request.validate()` before processing
2. Convert Request enum values to Domain types via `.toDomain`
3. Convert Domain entities to Response types via `Response(from:)` initializers
4. Delegate business logic to Domain Services — never implement it here

## Thin use case — single Domain Service delegation

A use case that delegates directly to one Domain Service method is **not a smell** — it is load-bearing architecture. Callers always import from `UseCases/`. They never need to ask "should I call the Domain Service directly or the use case?".

```swift
// Good — thin pass-through by design
final class FetchLibraryUseCase: FetchLibraryUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    func execute(_ request: FetchLibraryRequest) async throws -> [String] {
        try request.validate()
        return try await domainService.fetchAllIdentifiers()
    }
}
```

## Prohibitions

- Never import `SwiftUI`, `UIKit`, `SwiftData`, or `Photos` — enforced by SwiftLint
- Never import `Repositories/Protocols` — route through Domain Services
- Never inject concrete infrastructure, repository, or Domain Service classes — inject protocols only
- Never hold `@Published` state or `@Observable` — that belongs in ViewModels
- Never annotate `@MainActor` — use cases are actor-agnostic
- Never add display logic (formatting, localized strings) — that belongs in Presentation
- Never define a protocol in the same file as its implementation — protocols live in `Protocols/`
- Never return Domain Entity types to callers — always map to Response types
- Never accept primitive parameters — always accept a UseCaseRequest struct
