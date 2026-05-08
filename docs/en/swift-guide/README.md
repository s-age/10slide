# Swift Beginner's Guide — Learn Swift Through 10slide's Code

> Audience: People who are just starting to learn Swift. Understand "why is it written this way?" by reading real application code.

This guide uses the source code of the macOS slideshow app **10slide** as teaching material to explain everything from Swift fundamentals to architecture patterns. Each chapter corresponds to an actual source file, so you can learn by reading the code alongside the explanations.

Additionally, each chapter includes **Pitfalls** that were actually encountered during development. Practical knowledge like "this looks like it works but actually breaks" is something you cannot get from textbooks alone.

---

## Part 1: Layer-by-Layer Guide

10slide is built with the following layered architecture. Let's learn each layer's role and code examples from top to bottom.

```
Presentation → UseCases → Domain/Services → Repositories → Infrastructure
                              ↑
                         Domain/Entities
                         Errors (shared leaf layer)
```

### App — Entry Point

| Chapter | What You'll Learn |
|---------|-------------------|
| [TenSlideApp](App/TenSlideApp.md) | `@main`, `App` protocol, `WindowGroup`, booting the DI container |

### Presentation — UI and User Interaction

| Chapter | What You'll Learn |
|---------|-------------------|
| [SlideshowPlayerView](Presentation/SlideshowPlayerView.md) | SwiftUI view composition, `ZStack`/`HStack`, `.task`, gesture handling, `@ViewBuilder`, transitions |
| [SlideshowPlayerViewModel](Presentation/SlideshowPlayerViewModel.md) | `@Observable`, `@MainActor`, `async/await`, `Task` management |

### UseCases — Use Cases

| Chapter | What You'll Learn |
|---------|-------------------|
| [CreateSlideshowUseCase](UseCases/CreateSlideshowUseCase.md) | UseCase pattern, Request/Response, `typealias` with `any`, generics |

### Domain — Business Logic

| Chapter | What You'll Learn |
|---------|-------------------|
| [Slide / Slideshow / SlideshowConfig / SlideDuration / TransitionType](Domain/Slide.md) | `struct`, `enum`, `Identifiable`, `Equatable`, `Sendable`, `CaseIterable`, factory methods |
| [SlideshowDomainService](Domain/SlideshowDomainService.md) | Domain Service pattern, calling Repository protocols |

### Repositories — Data Access Abstraction

| Chapter | What You'll Learn |
|---------|-------------------|
| [SlideshowRepository](Repositories/SlideshowRepository.md) | Repository pattern, DTO conversion, bridging with SwiftData |

### DI — Dependency Injection

| Chapter | What You'll Learn |
|---------|-------------------|
| [Container](DI/Container.md) | DI container, `final class`, layer-by-layer dependency wiring |

### Infrastructure — External System Integration

| Chapter | What You'll Learn |
|---------|-------------------|
| [SwiftDataStore](Infrastructure/SwiftDataStore.md) | `@ModelActor`, generics, `@Sendable` closures, SwiftData operations |

---

## Part 2: Topic-Based Advanced Guides

Deep dives into themes that cut across layers. These are most effective after reading Part 1.

| Chapter | What You'll Learn |
|---------|-------------------|
| [Swift Concurrency in Practice](Topics/SwiftConcurrency.md) | `Sendable`, `@MainActor`, `Task.detached`, `@ModelActor`, `Mutex` |
| [SwiftData in Practice](Topics/SwiftDataPractice.md) | Parent-child insertion order, orphan records, migration, DTO pattern |
| [Testing Patterns in Practice](Topics/TestingPatterns.md) | Async testing, `@Model` fixtures, parameterizing timers |
| [Error Design Guide](Topics/ErrorDesign.md) | Shared leaf layer, `LocalizedError`, error type design principles |

---

## Recommended Reading Order

1. **Complete Swift beginner** -- Start with Domain/Slide.md. Learn the basics of `struct`, `enum`, and protocol conformance
2. **Want to learn SwiftUI** -- Read the two Presentation chapters. Understand the relationship between Views and ViewModels
3. **Want to understand the architecture** -- Read in order: DI/Container.md, UseCases, Domain, Repositories, Infrastructure
4. **Want to know practical pitfalls** -- Check the "Pitfalls Learned in Practice" section at the end of each chapter, as well as the topic-based guides in Part 2

The "Pitfalls" sections in each chapter are based on real cases that Claude encountered and debugged during actual development. They explain "why this approach doesn't work" with specific error messages and behaviors, providing clues for solving the same problems when you encounter them.
