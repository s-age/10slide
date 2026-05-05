---
paths:
  - 'Sources/UseCases/**/*.swift'
---

## Role

Provides a **stable, uniform API surface** for the Presentation layer. UseCases accept Request structs, delegate to Domain Services, and return Response types. They never touch Repositories directly.

## Directory layout

```
UseCases/
├── Protocols/     # AsyncUseCase / SyncUseCase base protocols + *UseCaseProtocol typealiases
├── Decorators/    # Cross-cutting concern decorators (validation, etc.)
├── Requests/      # UseCaseRequest protocol + concrete Request structs
├── Responses/     # Response structs + Response enums + mapping extensions
└── *.swift        # Concrete implementations
```

## Base protocols and typealiases

All use cases conform to one of two base protocols:

```swift
// Async use cases (I/O, persistence, network)
protocol AsyncUseCase<Request, Response>: Sendable {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) async throws -> Response
}

// Sync use cases (pure computation, no I/O)
protocol SyncUseCase<Request, Response>: Sendable {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) throws -> Response
}
```

Each use case's public contract is a typealias in `Protocols/`, not a standalone protocol. Never replace these typealiases with standalone protocols — the base generic protocols (`AsyncUseCase`, `SyncUseCase`) already provide the contract; per-use-case protocols would duplicate it without benefit.

```swift
// Protocols/CreateSlideshowUseCaseProtocol.swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>

// Protocols/AdvanceSlideUseCaseProtocol.swift
typealias AdvanceSlideUseCaseProtocol = any SyncUseCase<AdvanceSlideRequest, Int?>
```

Presentation and DI layers use the typealias name directly — no `any` prefix (it is already embedded in the typealias).

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation` | `SwiftUI`, `UIKit`, `SwiftData`, `Photos` |
| `Domain/Entities` (for Entity → Response mapping) | `Repositories/Protocols` (route through Domain Services) |
| `Domain/Services/Protocols/` | `Infrastructure` (concrete or protocol) |
| `Errors/` (shared error types) | |
| `Requests/`, `Responses/` (intra-layer) | |

## Request/Response pattern

Every UseCase follows this uniform shape:

```swift
// Typealias (in Protocols/)
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>

// Implementation — conforms to AsyncUseCase directly
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
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
1. **Do not** call `request.validate()` in concrete use cases — the `ValidationUseCaseDecorator` handles this transparently in the DI layer
2. Convert Request enum values to Domain types via `.toDomain`
3. Convert Domain entities to Response types via `Response(from:)` initializers
4. Delegate business logic to Domain Services — never implement it here
5. Each use case has exactly one `execute` method (Command pattern — 1 UseCase = 1 Action)

## Decorator pattern

Cross-cutting concerns (validation, future logging/caching) are handled by decorators in `Decorators/`, not by concrete use cases. The DI container wraps each use case with the appropriate decorator(s).

```swift
// DI wiring — decorator wraps the concrete use case
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)
```

New decorators should follow the same shape as `ValidationAsyncUseCaseDecorator` / `ValidationSyncUseCaseDecorator`.

## Thin use case — single Domain Service delegation

A use case that delegates directly to one Domain Service method is **not a smell** — it is load-bearing architecture. Callers always import from `UseCases/`. They never need to ask "should I call the Domain Service directly or the use case?".

```swift
// Good — thin pass-through by design
final class FetchLibraryUseCase: AsyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    func execute(_ request: FetchLibraryRequest) async throws -> [String] {
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
- Never call `request.validate()` in a concrete use case — the decorator handles it
- Never put multiple `execute` methods in one use case — split into separate use cases
- Never make a sync use case async — use `SyncUseCase` for pure computation
