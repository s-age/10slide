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
| `UseCaseContainer` | Use case instances (injected with repository protocols) |
| `PresentationContainer` | ViewModel factories or instances (injected with use case protocols) |

## Patterns

**Properties typed as protocols** — containers hold concrete objects but expose them as protocol types

```swift
// Good — RepositoryContainer exposes a protocol type
let slideRepository: any SlideRepositoryProtocol

// Acceptable — InfrastructureContainer exposes ModelContainer (no protocol available)
let modelContainer: ModelContainer
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
