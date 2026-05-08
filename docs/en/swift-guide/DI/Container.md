# Understanding DI Containers — A Complete Guide to Dependency Injection

> Audience: People who are just starting to learn Swift. Those who read code and wonder "why is it written this way?"

---

## Target Files

| File | Role |
|------|------|
| `Sources/DI/Container.swift` | The "wiring diagram" for the entire app. Creates all layer containers in a fixed order |
| `Sources/DI/InfrastructureContainer.swift` | Infrastructure layer container. Holds `ModelContainer`, data stores, and data sources |
| `Sources/DI/RepositoryContainer.swift` | Repository layer container. Holds repository instances injected with infrastructure protocols |
| `Sources/DI/DomainContainer.swift` | Domain layer container. Holds domain service instances injected with repository protocols |
| `Sources/DI/UseCaseContainer.swift` | UseCase layer container. Holds each use case wrapped in a validation decorator |
| `Sources/DI/PresentationContainer.swift` | Presentation layer container. Provides factory methods for assembling ViewModels |

---

## 1. What Is the DI (Dependency Injection) Pattern — Why Not Just `new` Directly?

### Definition

DI (Dependency Injection) is a design pattern where an object **receives the other objects it needs (dependencies) from the outside, rather than creating them itself**.

### Why Is It Used Here?

For example, `SlideshowPlayerViewModel` needs "the ability to load slide images." If it tried to create this itself, it would look like this:

```swift
// ❌ Without DI — ViewModel creates its own dependencies
class SlideshowPlayerViewModel {
    private let loader = LoadSlideImageUseCase(
        domainService: ImageService(
            repository: ImageRepository(
                store: SwiftDataImageStore()
            )
        )
    )
}
```

This has serious problems:

- **Untestable** — `SwiftDataImageStore` connects to a real database, so it cannot be swapped out during testing
- **Changes cascade** — If the initialization of `SwiftDataImageStore` changes, every place that uses it must be updated
- **Mixed responsibilities** — The ViewModel knows too much about "how to build things"

With DI, the ViewModel simply "uses what it's given from outside."

```swift
// ✅ With DI — ViewModel just uses the dependency it receives
class SlideshowPlayerViewModel {
    private let loadSlideImage: LoadSlideImageUseCaseProtocol

    init(loadSlideImage: LoadSlideImageUseCaseProtocol) {
        self.loadSlideImage = loadSlideImage
    }
}
```

The **DI container** that we'll study here is what takes on the single responsibility of "who passes which implementation to whom."

---

## 2. Reading `Container.swift`

```swift
final class Container {
    let infrastructure: InfrastructureContainer
    let repositories: RepositoryContainer
    let domain: DomainContainer
    let useCases: UseCaseContainer
    let presentation: PresentationContainer

    init() throws {
        infrastructure = try InfrastructureContainer()
        repositories = RepositoryContainer(infrastructure: infrastructure)
        domain = DomainContainer(repositories: repositories)
        useCases = UseCaseContainer(domain: domain)
        presentation = PresentationContainer(useCases: useCases)
    }
}
```

This file is only 15 lines, but it functions as the "wiring diagram" for the entire app.

---

### 2-1. `final class` — Why Prohibit Inheritance

#### Definition

Adding `final` to a class makes it **impossible to inherit from**.

```swift
final class Container { ... }

// ❌ Compile error — cannot inherit from a final class
class SpecialContainer: Container { }
```

#### Why Is It Used Here?

The DI container is "the manager responsible for wiring all objects." If parts could be overridden through inheritance, the wiring integrity would break down. Adding `final` explicitly states "this class will not be further specialized."

Also, `final class` allows the compiler to **optimize method dispatch**, slightly improving performance.

#### What If You Didn't Use `final`?

With `class Container`, someone could create a subclass that modifies part of the initialization, introducing unexpected dependencies.

---

### 2-2. `let` Properties — Immutable Dependencies

#### Definition

Properties declared with `let` **cannot be changed after initialization**.

```swift
let infrastructure: InfrastructureContainer
// infrastructure = other  // ❌ Compile error
```

#### Why Is It Used Here?

The objects held by the DI container are assembled once at app startup and never change afterward. Using `let` declares to the compiler that "this dependency will not be swapped out mid-execution."

#### What If You Used `var`?

```swift
var infrastructure: InfrastructureContainer  // ❌ Can be replaced later
```

With `var`, some code could write `container.infrastructure = anotherInfrastructure` and break the wiring.

---

### 2-3. `init() throws` — An Initializer That Allows Failure

#### Definition

A normal initializer `init()` always succeeds. Adding `throws` allows it to **fail and throw an error**.

```swift
init() throws {
    infrastructure = try InfrastructureContainer()  // Might fail
    ...
}
```

The caller uses `try` and `catch` to handle potential failure.

```swift
do {
    let container = try Container()
} catch {
    // Database initialization failure, etc.
    print("Startup failed: \(error)")
}
```

#### Why Is It Used Here?

Inside `InfrastructureContainer`, SwiftData (database) initialization takes place. Disk access can fail, schema migration can produce errors -- these are realistically possible failures. Using `throws` allows the failure to be communicated to the caller rather than being silently swallowed.

#### What If You Didn't Use `throws`?

There would be no way to communicate failures as errors. A commonly seen bad alternative is `fatalError()`, which only shows the user a crash with no chance of recovery.

---

### 2-4. Dependency Initialization Order — infrastructure, repositories, domain, useCases, presentation

```swift
infrastructure = try InfrastructureContainer()         // 1. Bottom layer
repositories = RepositoryContainer(infrastructure: infrastructure)  // 2.
domain = DomainContainer(repositories: repositories)               // 3.
useCases = UseCaseContainer(domain: domain)                        // 4.
presentation = PresentationContainer(useCases: useCases)           // 5. Top layer
```

#### Definition

This order corresponds to the app's architecture (layer structure).

```
Presentation (UI)
    ↓ uses
UseCases (feature units)
    ↓ uses
Domain (business logic)
    ↓ uses
Repositories (data conversion)
    ↓ uses
Infrastructure (actual DB, files, network)
```

#### Why This Order?

Upper layers depend on lower layers, so you must create the lower layers first before you can initialize the upper ones. For example, `RepositoryContainer` is initialized by receiving `infrastructure`, so it cannot be created until `infrastructure` is complete.

#### What If You Reversed the Order?

```swift
// ❌ This is a compile error — infrastructure doesn't exist yet
repositories = RepositoryContainer(infrastructure: infrastructure)
infrastructure = try InfrastructureContainer()
```

Swift's `let` properties must be initialized before use, so the compiler produces an error.

---

## 3. Reading `UseCaseContainer.swift`

```swift
final class UseCaseContainer: Sendable {
    let createSlideshow: CreateSlideshowUseCaseProtocol
    let fetchSlideshow: FetchSlideshowUseCaseProtocol
    // ... other use cases follow the same pattern ...

    init(domain: DomainContainer) {
        createSlideshow = ValidationAsyncUseCaseDecorator(
            decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
        )
        // ...
    }
}
```

---

### 3-1. `Sendable` Protocol — Thread-Safe Types

#### Definition

`Sendable` is a protocol that guarantees Swift's **concurrency safety**. A type conforming to this protocol declares to the compiler that "it can be safely passed between multiple threads or actors (concurrent execution contexts)."

```swift
final class UseCaseContainer: Sendable { ... }
```

#### Why Is It Used Here?

Modern iOS/macOS apps use `async/await` for concurrent processing. Use cases may be called from the UI (`@MainActor`) on a background thread. Declaring `Sendable` proves to the compiler that "this type can be safely passed to another actor."

Conditions for `Sendable` to hold:

1. Must be a `final class` (subclasses cannot add state)
2. All properties must be `let` (cannot be mutated)
3. All property types must be `Sendable` (safety chains through)

```swift
// ✅ All conditions met, so Sendable conformance holds
final class UseCaseContainer: Sendable {
    let createSlideshow: CreateSlideshowUseCaseProtocol  // Protocol is also declared Sendable
}
```

#### What If `Sendable` Were Missing?

In this codebase, which has Swift 6's strict concurrency checking enabled, passing a non-`Sendable` type from `@MainActor` code to an async context results in a compile error.

---

### 3-2. `any Protocol` Type — Storing in Containers with Protocol Existential Types

#### Definition

When using a Swift protocol as a type, adding the `any` keyword makes it a **protocol existential type**. It's a box that can store "some type that conforms to this protocol."

```swift
// Protocol definition
protocol CreateSlideshowUseCaseProtocol: Sendable {
    func execute(request: CreateSlideshowRequest) async throws -> SlideshowResponse
}

// Stored as an existential type with any
let createSlideshow: CreateSlideshowUseCaseProtocol
//                   ↑ This is actually shorthand for `any CreateSlideshowUseCaseProtocol` (typealias)
```

#### Why Is It Used Here?

If the container knew the concrete implementation class type, it would depend on that implementation. By storing as a protocol type, the design becomes **swappable**.

```swift
// ✅ Stored as protocol type — doesn't know the implementation
let createSlideshow: CreateSlideshowUseCaseProtocol

// The actual stored value is a concrete type wrapped in a decorator
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)
```

#### What If You Stored the Concrete Type?

```swift
// ❌ Stored as concrete type — implementation details leak out
let createSlideshow: ValidationAsyncUseCaseDecorator<CreateSlideshowUseCase>
```

It becomes impossible to swap in a mock implementation during testing.

---

### 3-3. Decorator Pattern — `ValidationAsyncUseCaseDecorator`

```swift
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)
```

#### Definition

The decorator pattern is a design pattern that **adds functionality by wrapping an existing object in another object**.

In this case, `CreateSlideshowUseCase` (the core processing) is wrapped with `ValidationAsyncUseCaseDecorator` (validation functionality).

```
ValidationAsyncUseCaseDecorator (outer — handles validation)
    └─ CreateSlideshowUseCase (inner — handles actual processing)
```

#### Why Is It Used Here?

If validation logic were written in each use case class, the same code would be duplicated across all use cases. By separating it as a decorator, the core use case can focus solely on business logic.

#### Two Decorator Variants

The codebase uses two decorator variants depending on whether the use case is asynchronous or synchronous:

| Decorator | Use case type | Example |
|-----------|--------------|---------|
| `ValidationAsyncUseCaseDecorator` | `AsyncUseCase` (async/await) | `CreateSlideshowUseCase`, `FetchSlideshowUseCase`, etc. |
| `ValidationSyncUseCaseDecorator` | `SyncUseCase` (synchronous) | `AdvanceSlideUseCase`, `PreviousSlideUseCase`, `AddDroppedFilesUseCase` |

```swift
// Async use case — wrapped with ValidationAsyncUseCaseDecorator
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)

// Sync use case — wrapped with ValidationSyncUseCaseDecorator
advanceSlide = ValidationSyncUseCaseDecorator(
    decoratee: AdvanceSlideUseCase(domainService: domain.playbackService)
)
```

---

## 4. Reading `PresentationContainer.swift`

```swift
final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol
    private let loadSlideImage: LoadSlideImageUseCaseProtocol
    // ...

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        // ...
    }

    @MainActor
    func makeThumbnailViewModel() -> ThumbnailViewModel {
        ThumbnailViewModel(loadThumbnail: loadThumbnail)
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: SlideshowResponse) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(
            slideshow: slideshow,
            loadSlideImage: loadSlideImage,
            ...
        )
    }
}
```

---

### 4-1. `private let` — Information Hiding (Encapsulation)

```swift
private let createSlideshow: CreateSlideshowUseCaseProtocol
```

#### Definition

Adding `private` makes the property **accessible only from within the same file**. It is invisible to external code.

#### Why Is It Used Here?

The use cases held by `PresentationContainer` are used only for assembling ViewModels. If external code could directly access `container.createSlideshow`, dependencies could be used without going through the container. Hiding them with `private` forces all external usage to go through `make*` factory methods.

---

### 4-2. `init` Drops the Container Reference — Immediate Extraction of Protocol Values

```swift
init(useCases: UseCaseContainer) {
    createSlideshow = useCases.createSlideshow   // Extract the protocol value
    loadSlideImage = useCases.loadSlideImage     // Extract the protocol value
    // useCases itself is NOT saved as a property!
}
```

#### Why Not Save `useCases` Directly?

If `UseCaseContainer` were saved as a property, `PresentationContainer` would depend on "the entire use case layer container." If something were later added to `UseCaseContainer`, it would be affected.

By extracting only the protocol values inside `init` and discarding the reference to the container, only the necessary dependencies are kept to a minimum. This is known as the **"drop the upstream container" pattern**.

---

### 4-3. `@MainActor` — Guaranteeing the UI Thread

#### Definition

`@MainActor` is an annotation that makes the compiler guarantee "this function runs on the main thread." SwiftUI Views must always run on the main thread.

```swift
@MainActor
func makeThumbnailViewModel() -> ThumbnailViewModel {
    ThumbnailViewModel(loadThumbnail: loadThumbnail)
}
```

#### Why Is It Used Here?

`ThumbnailViewModel` and similar types perform UI updates using `@Observable` or `@Published`, so they need to be created on the main thread. Adding `@MainActor` causes a compile error if they are accidentally called from a background thread.

#### What If `@MainActor` Were Missing?

A ViewModel might be created from a background thread, causing UI updates to happen off the main thread, which could lead to crashes.

---

### 4-4. Factory Methods — ViewModel Assembly Responsibility

```swift
@MainActor
func makeSlideshowPlayerViewModel(slideshow: SlideshowResponse) -> SlideshowPlayerViewModel {
    SlideshowPlayerViewModel(
        slideshow: slideshow,
        loadSlideImage: loadSlideImage,
        updateSlideshowConfig: updateSlideshowConfig,
        advanceSlide: advanceSlide,
        previousSlide: previousSlide
    )
}
```

#### Definition

A factory method is a **dedicated method responsible for creating objects**. The caller doesn't need to know "how to build it" -- they just pass "what they want" (arguments) and receive the finished product.

#### Why Is It Used Here?

`SlideshowPlayerViewModel` requires four dependencies: `loadSlideImage`, `updateSlideshowConfig`, `advanceSlide`, and `previousSlide`. For the View (the caller) to pass these directly, the View itself would need to know about all of them.

```swift
// ❌ Without a factory — View must know all dependencies
SlideshowPlayerViewModel(
    slideshow: slideshow,
    loadSlideImage: ???,   // Where does the View get this?
    ...
)
```

Going through a factory method means the View only needs to know about `slideshow` (the data to display).

```swift
// ✅ With a factory — View only needs to pass slideshow
let vm = container.presentation.makeSlideshowPlayerViewModel(slideshow: slideshow)
```

#### Using as a Factory Closure

`@MainActor` methods can also be passed around as closures.

```swift
// Expressing the type of makePlayerViewModel as a closure:
// @MainActor @Sendable (SlideshowResponse) -> SlideshowPlayerViewModel

// Pass only "the method for creating ViewModels" to the View (not the entire container)
let factory: @MainActor (SlideshowResponse) -> SlideshowPlayerViewModel
    = container.presentation.makeSlideshowPlayerViewModel
```

The meaning of each part of this type signature:

| Part | Meaning |
|------|---------|
| `@MainActor` | This closure runs on the main thread |
| `@Sendable` | This closure can be safely passed to another actor |
| `(SlideshowResponse)` | Argument: the slideshow data to display |
| `-> SlideshowPlayerViewModel` | Return value: the completed ViewModel |

---

## 5. Pitfalls Learned in Practice

These are problems that were actually encountered during this project's development. Important points to know in order to avoid patterns that "seem to work but aren't correct" in DI container design.

---

### Pitfall 1: Making DI Containers `Sendable`

#### What Happens

In environments with Swift 6's strict concurrency checking enabled, passing a DI container's method reference as a `@Sendable` closure produces a compiler warning if the container is not `Sendable`.

```
warning: converting non-Sendable function value to
'@MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel' may introduce data races
```

In this project, `ContentView` was designed to receive factory methods from `PresentationContainer` as closures, and this warning occurred because `PresentationContainer` was not `Sendable`.

#### Correct Approach

```swift
// ✅ final class + let only + all properties Sendable → Sendable conformance holds automatically
final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol  // typealias embeds `any`
    private let loadSlideImage: LoadSlideImageUseCaseProtocol    // typealias embeds `any`

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
    }
}
```

Remember the three conditions for `Sendable` to hold:

1. Must be a `final class` (subclasses cannot add state)
2. All properties must be `let` (cannot be mutated)
3. All property types must be `Sendable` (safety chains through)

#### What NOT to Do

```swift
// ❌ Having a var property makes Sendable impossible
final class PresentationContainer: Sendable {
    private var createSlideshow: any CreateSlideshowUseCaseProtocol  // Compile error!
}

// ❌ Faking it with @unchecked Sendable — discards the compiler's protection
final class PresentationContainer: @unchecked Sendable {
    private var createSlideshow: any CreateSlideshowUseCaseProtocol
    // Data race risk remains...
}
```

**Key takeaway**: Silencing warnings with `@unchecked Sendable` or `nonisolated(unsafe)` should be a last resort. First consider whether you can make the container correctly `Sendable`.

---

### Pitfall 2: Maintaining Linear Layer Dependencies

#### What Happens

When you think "I could just call the Repository directly from the UseCase -- it would be simpler," and skip the Domain Service, a **layer skip** occurs. This project does not use Clean Architecture's V-shaped flow, but instead adopts a **strict linear flow**.

```
Presentation → UseCases → Domain Services → Repositories → Infrastructure
```

Skipping layers triggers an error from SwiftLint's custom rules. But more importantly, business logic becomes scattered, leading to a state where "the same processing is written in multiple places."

#### Correct Approach

```swift
// ✅ UseCase only calls DomainService (does not call Repository)
final class CreateSlideshowUseCase {
    private let domainService: SlideshowServiceProtocol

    func execute(request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        let entity = try await domainService.create(name: request.name)
        return SlideshowResponse(entity)
    }
}
```

#### What NOT to Do

```swift
// ❌ UseCase is calling Repository directly (layer skip)
final class CreateSlideshowUseCase {
    private let repository: SlideshowRepositoryProtocol  // Skipping the Domain Service!

    func execute(request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        let entity = try await repository.save(...)
        return SlideshowResponse(entity)
    }
}
```

**Key takeaway**: Even when you think "this only does one thing, so I can skip the Domain Service," always follow the rule of calling only the adjacent layer. This ensures that Repository orchestration (processing that combines multiple operations) always resides in the Domain Service, maintaining a consistent design.

---

## 6. What You Can Learn from This File -- Summary

| Concept | Keyword | Summary |
|---------|---------|---------|
| **DI pattern** | `init(useCases:)` | Gain testability and resilience to change by "passing dependencies from outside" |
| **`final class`** | `final` | Prohibit inheritance to protect design intent and optimization |
| **`let` properties** | `let` | Prohibit changes after initialization, guaranteeing immutable dependencies |
| **`init() throws`** | `throws` / `try` | Propagate initialization failures as errors, avoiding crashes |
| **Initialization order** | lower → upper | Build what is depended on first. Reversing causes compile errors |
| **`Sendable`** | `: Sendable` | Prove to the compiler that the type can be safely passed between actors in concurrent processing |
| **`any Protocol` type** | `XxxProtocol` | Depend on abstractions rather than concrete implementations, enabling substitution |
| **Factory methods** | `make*()` / `@MainActor` | Hide complex assembly steps and keep the caller simple |

### The Overall Flow in One Sentence

> `Container` assembles all dependencies once at app startup, each sub-container holds only the dependencies it needs with `private let`, and ViewModels are received from outside via factory methods.

This design achieves an **app that is easy to test, resilient to change, and thread-safe**.
