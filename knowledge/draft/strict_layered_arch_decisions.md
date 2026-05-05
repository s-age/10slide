# Strict Layered Architecture — Key Decisions & Gotchas

## Why strict layered over Clean Architecture V-shape

Clean Architecture allows UseCases to fan out to both Entities and Repositories (V-shape). This creates ambiguity about where Repository orchestration belongs — it leaks into UseCases as a side effect. The strict linear flow (UseCase → Domain Service → Repository → Infrastructure) eliminates this: every layer talks only to its immediate neighbor, making violation detection mechanically trivial for both SwiftLint and AI code generation.

## Swift 6 forced protocol-based Request (not class inheritance)

Original design called for a base class (`class UseCaseRequest`) with subclass inheritance for validation enforcement. Swift 6 Strict Concurrency makes this impractical: a non-final class cannot conform to `Sendable`, and `@unchecked Sendable` is banned by project rules. Solution: `protocol UseCaseRequest: Sendable` with struct conformers — achieves the same contract (forced `validate()`) while getting automatic Sendable for free.

## `toDomain` visibility leak

`SlideDurationResponse.toDomain`, `TransitionTypeResponse.toDomain`, and `SlideshowConfigResponse.toDomain` are UseCase-internal helpers for converting Response enums back to Domain types (used when building Domain objects from Request data). Since the app is a single target, these are `internal` and technically callable from Presentation. Current mitigation: SwiftLint rules + arch rule documentation. Future mitigation if needed: Swift Package modularization.

## UpdateSlideshowConfig and the fetch trade-off

`UpdateSlideshowConfigUseCase` fetches the slideshow from the repository before applying the config change. This adds a DB roundtrip for what was previously a pure in-memory transformation. Accepted trade-off for architectural consistency. If performance becomes an issue, the Request could carry the full slideshow state to avoid the fetch.

## Domain entity method removal

`Slideshow.nextSlideIndex(from:)` and `Slideshow.previousSlideIndex(from:)` were removed after logic moved to `PlaybackDomainService`. Entities should remain pure data containers — behavioral methods that don't depend on the entity's own state (only on passed-in parameters) belong in Domain Services.
