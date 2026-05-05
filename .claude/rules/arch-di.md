---
paths:
  - 'Sources/DI/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/DI/`:

- **Layer responsibility**: Wires all layers together. The only place in the app that may hold references to concrete classes across layers. DI containers have intentionally high coupling — SwiftLint complexity rules are excluded here (see `.swiftlint.yml`).
- **Rule**: Each layer has exactly one container. Containers are initialized in dependency order inside `Container.swift`.

## Boot order

```swift
// Container.swift — always this order
infrastructure = try InfrastructureContainer()
repositories = RepositoryContainer(infrastructure: infrastructure)
useCases = UseCaseContainer(repositories: repositories)
presentation = PresentationContainer(useCases: useCases)
```

## Container responsibilities

| Container | Owns |
|-----------|------|
| `InfrastructureContainer` | `ModelContainer`, data source instances |
| `RepositoryContainer` | Repository instances (injected with infra protocols) |
| `UseCaseContainer` | Use case instances wrapped in decorators (injected with domain service protocols) |
| `PresentationContainer` | ViewModel factories or instances (injected with use case protocols) |

## Patterns

**Properties typed as protocol typealiases** — containers hold concrete objects but expose them via UseCase typealiases (which embed `any` already — do not add `any` prefix)

```swift
// Good — UseCaseContainer exposes a typealias type (no `any` prefix)
let createSlideshow: CreateSlideshowUseCaseProtocol

// Good — RepositoryContainer exposes a protocol type
let slideRepository: any SlideRepositoryProtocol

// Acceptable — InfrastructureContainer exposes ModelContainer (no protocol available)
let modelContainer: ModelContainer
```

**UseCase decorator wrapping** — `UseCaseContainer` wraps each concrete use case with the appropriate validation decorator

```swift
// Good — decorator wraps the concrete use case
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)

// Bad — exposing a bare concrete use case without decorator
createSlideshow = CreateSlideshowUseCase(domainService: domain.slideshowService)  // NG: no validation
```

**Only `Container.swift` instantiates sub-containers**

```swift
// Good — Container.swift owns all wiring
final class Container {
    let infrastructure: InfrastructureContainer
    let repositories: RepositoryContainer

    init() throws {
        infrastructure = try InfrastructureContainer()
        repositories = RepositoryContainer(infrastructure: infrastructure)
    }
}

// Bad — a sub-container creates its own infrastructure
final class RepositoryContainer {
    init() {
        let infra = InfrastructureContainer()   // NG: only Container.swift may do this
    }
}
```

## Sendable conformance

A `final class` container whose stored properties are all `let` and all protocol existentials that themselves declare `: Sendable` satisfies `Sendable` without `@unchecked`. Declare it explicitly so that method references from the container can be passed as `@Sendable` closures.

```swift
// Good — all stored properties are let Sendable existentials (typealiases embed `any`)
final class PresentationContainer: Sendable {
    private let fetchSlideshows: FetchSlideshowsUseCaseProtocol  // typealias is Sendable existential
    // ...
}

// Bad — @unchecked hides the real problem; fix the protocol or property instead
final class PresentationContainer: @unchecked Sendable { ... }  // NG
```

Not all containers qualify: `InfrastructureContainer` holds `ModelContainer` (not `Sendable`), so it cannot declare `Sendable`. Only add it when the stored types genuinely satisfy the constraint.

## Protocol extraction pattern

Sub-containers receive an upstream container in `init()` but must **extract protocol-typed properties immediately** and discard the container reference. This prevents cross-layer coupling and hidden dependencies.

```swift
// Good — extract protocols at init, discard container
final class RepositoryContainer {
    let slideRepository: any SlideRepositoryProtocol

    init(infrastructure: InfrastructureContainer) {
        slideRepository = SlideRepository(
            slideDataSource: infrastructure.slideDataSource
        )
        // infrastructure reference is NOT stored
    }
}

// Bad — storing the upstream container as a property
final class RepositoryContainer {
    private let infrastructure: InfrastructureContainer   // NG: retains cross-layer coupling

    init(infrastructure: InfrastructureContainer) {
        self.infrastructure = infrastructure
    }
}
```

## Prohibitions

- Never add business logic to a DI container
- Never let one sub-container reference another sub-container — only `Container.swift` knows all layers
- Never initialize dependencies lazily inside container properties — eagerly initialize in `init()`
- Never make a container `@Observable` or `ObservableObject` — inject individual use cases or ViewModels instead
- Never store an upstream container as a property — extract protocol values at init and discard
- Never use `@unchecked Sendable` on a container — make stored types genuinely `Sendable` or leave the conformance off
