# Learning the UseCase Pattern and Swift Concepts

## Target Files

| File | Role |
|---|---|
| `Sources/UseCases/Protocols/ExecutableUseCase.swift` | Protocol that defines the "type shape" of a UseCase |
| `Sources/UseCases/Requests/CreateSlideshowRequest.swift` | Input to the UseCase (what you want to do) |
| `Sources/UseCases/Responses/SlideshowResponse.swift` | Output from the UseCase (the result type) |
| `Sources/UseCases/CreateSlideshowUseCase.swift` | Implementation of the process that creates a slideshow |

### What You'll Learn in This Guide

We'll follow how a single operation -- "create a new slideshow" -- is expressed in Swift code, learning both the UseCase pattern's philosophy and Swift language features along the way.

---

## 1. Protocols and `associatedtype` -- Defining the "Type Shape"

### File: `ExecutableUseCase.swift`

```swift
protocol AsyncUseCase<Request, Response>: Sendable {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) async throws -> Response
}
```

### What Is a `protocol`

A protocol is a mechanism that requires conforming types to "have these methods." It demands of classes and structs: "at minimum, implement these."

**What if you didn't use one?**  
Each UseCase would use whatever method names it liked -- `run()`, `start()`, and so on, all different. The calling side (the Presentation layer) would need to write different code for each UseCase, losing all consistency.

### What Is `associatedtype`

It's a "type placeholder" for a protocol. It means "when you conform to this protocol, specify the concrete type."

```swift
// Protocol side: Request and Response are "to be determined later"
protocol AsyncUseCase<Request, Response> {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) async throws -> Response
}

// Implementation side: Here "Request = CreateSlideshowRequest" is finalized
final class CreateSlideshowUseCase: AsyncUseCase {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        // ...
    }
}
```

**What if you didn't use it?**  
The only option would be to make `execute`'s argument type `Any`, requiring a cast (type conversion) on the calling side every time. Type errors wouldn't be detected at compile time, and bugs would go unnoticed until runtime.

Thanks to `associatedtype`, the Swift compiler can check in advance that "you must pass a `CreateSlideshowRequest` to `CreateSlideshowUseCase`."

---

## 2. `typealias` -- Giving a Type an "Alias"

In this project, the public interface for each UseCase is defined as a `typealias` in the `Protocols/` folder.

```swift
// Protocols/CreateSlideshowUseCaseProtocol.swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>
```

### What Is `typealias`

A feature that gives an existing type an "alias." It's used to shorten long type names or to give them meaningful names.

### Why It's Used Here

The type `any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>` is too long to write every time. By naming it `CreateSlideshowUseCaseProtocol`, anyone reading the code can immediately understand "this is the UseCase for creating slideshows."

**What if you didn't use it?**  
The long type name would appear repeatedly in DI (dependency injection) code and ViewModel code. When changing the type, you'd need to update every single occurrence.

```swift
// Without an alias (hard to read)
init(useCase: any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>) { ... }

// With an alias (conveys intent)
init(useCase: CreateSlideshowUseCaseProtocol) { ... }
```

---

## 3. `final class` and Protocol Conformance -- "A Concrete Implementation That Keeps Its Promises"

### File: `CreateSlideshowUseCase.swift`

```swift
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        // ...
    }
}
```

### The Difference Between `class` and `struct`

Swift has value types (`struct`) and reference types (`class`).

- **struct (value type)**: Copied when assigned. Suited for simple bundles of data.
- **class (reference type)**: Multiple places can reference the same instance. Suited for objects that hold dependencies.

UseCase uses `class` because it holds a dependency object called `domainService`.

### What Is `final`

A declaration that "this class cannot be subclassed."

**What if you didn't use it?**  
Other classes could inherit from `CreateSlideshowUseCase` and override `execute`. Since UseCases follow a design of one operation = one class, `final` prevents inheritance from adding complexity. It also makes it easier for the compiler to optimize.

### Protocol Conformance (`: AsyncUseCase`)

Writing `: ProtocolName` after the class name declares "this class implements that protocol." The compiler verifies that the `execute` method is implemented and raises an error if it's missing.

---

## 4. `Sendable` -- Safe to Use in Concurrent Code

```swift
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
```

### What Is `Sendable`

In Swift's concurrency model (async/await), multiple tasks run simultaneously. `Sendable` is a guarantee that "this type can be safely passed between multiple tasks or threads."

**What if you didn't use it?**  
The Swift 6 compiler would issue warnings or errors saying "passing this type to an asynchronous task might be dangerous." Conformance to `Sendable` is required to use a UseCase inside an async function.

### Why `CreateSlideshowUseCase` Can Be `Sendable`

The `domainService` this class holds is of type `any SlideshowDomainServiceProtocol`, and that protocol itself conforms to `Sendable`. If all properties are `Sendable`, the entire class can be `Sendable` too.

---

## 5. Request / Response Pattern -- Expressing Input and Output with Types

### File: `CreateSlideshowRequest.swift`

```swift
struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let localIdentifiers: [String]
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
```

### Why Make Request a `struct`

A Request is "a bundle of information needed for this operation." Since it's just data, there's no problem with it being copied. A `struct` (value type) is the right fit.

**What if you didn't use it?**  
You'd end up with a method with 5 or more arguments like `execute(name: String, identifiers: [String], duration: ..., transition: ..., loop: Bool)`. It's easy to mix up the argument order, and every time you add a new field, you'd need to change all the calling code.

By grouping them into a Request type:
- Adding or changing fields only requires modifying the type definition
- `validate()` lets you write input validation in one place
- Anyone reading the code can see at a glance "what's needed for this operation"

> **Important**: `validate()` is **not** called inside `execute()` itself. It is called by the `ValidationAsyncUseCaseDecorator` that wraps the use case in the DI container. This means validation is automatically applied to every use case without the use case needing to call `validate()` explicitly. See [DI/Container.md](../DI/Container.md) for how this decorator wrapping works.

### File: `SlideshowResponse.swift`

```swift
struct SlideshowResponse: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let slides: [SlideResponse]
    let config: SlideshowConfigResponse
    let createdAt: Date
}
```

### Why Make Response a Separate Type

The Domain layer (business logic) has an entity type called `Slideshow`. However, if you pass the domain's internal type directly to the Presentation layer for display, any domain changes immediately affect the UI code.

By inserting a Response type as a "buffer":
- Even if the domain layer changes, the UI code doesn't need to change as long as the Response type stays the same
- You can selectively pass only the information needed for display (hiding unnecessary internal details)

`Identifiable` is a protocol that requires an `id` property, used by SwiftUI's `List` and loop constructs to uniquely identify each element. `Equatable` guarantees that values can be compared with `==`.

---

## 6. `async throws -> Response` -- An Asynchronous Function That Can Fail

```swift
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
```

### `async` -- Asynchronous Processing

A function marked with `async` is one that "can yield execution to other tasks midway." Creating a slideshow involves accessing disk or the photo library, which takes time. `async` is used so the app doesn't freeze during that time.

```swift
// The calling side uses await
let response = try await useCase.execute(request)
// Execution pauses here and resumes on the next line when complete
```

**What if you didn't use it?**  
With synchronous processing (no `async`), the entire app would freeze until the save completes. The user wouldn't be able to interact with the screen during that time.

### `throws` -- The Ability to Signal Failure

A function marked with `throws` can "throw" errors. The calling side calls it with `try` and can catch errors with `catch`.

```swift
// Example calling code
do {
    let response = try await useCase.execute(request)
    // Handle success
} catch ValidationError.emptyName {
    // Handle empty name
} catch {
    // Handle other errors
}
```

**What if you didn't use it?**  
You could use a `Result<SlideshowResponse, Error>` return type instead, but that tends to create deep nesting and harder-to-read code. `throws` is Swift's standard error propagation mechanism and allows more natural code.

---

## 7. `.toDomain` -- Type Conversion via Computed Properties

```swift
let config = SlideshowConfig(
    duration: request.duration.toDomain,  // Response type -> Domain type
    transition: request.transition.toDomain,
    loop: request.loop
)
```

### What Is a Computed Property

A property defined with `var` that calculates and returns a value each time it's accessed. Instead of a method that takes no arguments, it provides a natural way to get "the value of this type converted to another type."

```swift
// From ResponseMapping.swift
extension SlideDurationResponse {
    var toDomain: SlideDuration {
        switch self {
        case .five: .five
        case .ten: .ten
        case .fifteen: .fifteen
        case .thirty: .thirty
        case .sixty: .sixty
        case .manual: .manual
        }
    }
}
```

### Why `.toDomain` Is Needed

`SlideDurationResponse` (a Response layer type) and `SlideDuration` (a Domain layer type) are different things. Even though they represent the same concept of "5 seconds," each layer defines its own independent type. The UseCase acts as the "translator," converting the Response type to the Domain type before passing it to the Domain Service.

**What if you didn't use it?**  
The Presentation layer would directly use Domain layer types, breaking layer separation. When Domain types change, those changes would ripple all the way to the UI code.

### `init(from:)` -- Conversion in the Opposite Direction

The Domain -> Response conversion is done with `init(from:)`.

```swift
// From ResponseMapping.swift
extension SlideshowResponse {
    init(from entity: Slideshow) {
        self.init(
            id: entity.id,
            name: entity.name,
            slides: entity.slides.map { SlideResponse(from: $0) },
            config: SlideshowConfigResponse(from: entity.config),
            createdAt: entity.createdAt
        )
    }
}
```

The last line of the UseCase, `return SlideshowResponse(from: slideshow)`, calls this. It converts the Domain entity (`Slideshow`) into a Response type (`SlideshowResponse`) and returns it to the Presentation layer.

---

## Summary: What You Can Learn from This Code

| Concept | Key Point |
|---|---|
| `protocol` + `associatedtype` | Abstracts the "type shape," allowing different UseCases to be handled through a unified interface |
| `typealias` | Gives a long type name a meaningful alias, improving code readability and maintainability |
| `final class` + protocol conformance | A concrete implementation class that cannot be subclassed fulfills the protocol's promises |
| `Sendable` | Guarantees to the compiler that the type can be safely passed around in Swift 6 concurrency |
| `async throws -> Response` | A function signature that handles time-consuming operations asynchronously and treats failure explicitly |
| Request / Response pattern | Encapsulates input and output in dedicated types, minimizing dependencies between layers |
| `.toDomain` / `init(from:)` | Organizes cross-layer type conversions using computed properties and initializers |

---

## Pitfalls Learned in Practice

Here are pitfalls in the UseCase layer discovered from issues that actually occurred during this project's development.

---

### Pitfall 1: In Swift 6, Define Requests with `protocol + struct`

#### What Happens

People with object-oriented experience are tempted to define a common `validate()` method in a base class and implement each Request as a subclass. However, in Swift 6's Strict Concurrency, non-`final` classes cannot conform to `Sendable`. `@unchecked Sendable` is prohibited by this project's rules.

```swift
// Bad: Defining a common interface with a base class (compile error in Swift 6)
class UseCaseRequest: Sendable {  // Error: non-final class cannot be Sendable
    func validate() throws { }
}

class CreateSlideshowRequest: UseCaseRequest {
    let name: String
    // ...
    override func validate() throws {
        guard !name.isEmpty else { throw ValidationError.emptyName }
    }
}
```

```swift
// Good: Define with protocol + struct (Sendable is automatically synthesized)
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let localIdentifiers: [String]
    // ... if all properties are Sendable, the struct is automatically Sendable

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
    }
}
```

If all stored properties of a `struct` are `Sendable`, the compiler automatically synthesizes `Sendable` conformance. Defining common interfaces with protocols rather than relying on class inheritance is the correct approach in Swift 6.

---

### Pitfall 2: Don't Double-Write `any` When It's Embedded in a `typealias`

#### What Happens

In this project, UseCase protocol types are defined using `typealias`.

```swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>
//                                         ^^^ any is embedded here
```

In Swift, you normally add `any` when using a protocol type. But since this `typealias` already contains `any`, adding another `any` at the usage site causes a compile error.

```swift
// Bad: Adding any even though the typealias already contains any
let createSlideshow: any CreateSlideshowUseCaseProtocol
// Compile error: redundant 'any' in type

// Bad: Trying to conform a concrete class to the typealias (an existential type)
final class CreateSlideshowUseCase: CreateSlideshowUseCaseProtocol { ... }
// Compile error: cannot conform to an existential type
```

```swift
// Good: Use the typealias as-is (no any needed)
let createSlideshow: CreateSlideshowUseCaseProtocol

// Good: Conform the concrete class to the original protocol (AsyncUseCase)
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        // ...
    }
}
```

**Remember:** Check the `typealias` definition before using it. A `typealias` that already contains `any` can be used directly as a type.

---

### Summary of the UseCase's Role

```
Presentation Layer       UseCase Layer             Domain Layer
-------------------------------------------------------------
CreateSlideshowRequest --> execute() --> SlideshowConfig
(input received from UI)    | toDomain conversion      |
                         Calls domainService.create()
                              |
SlideshowResponse <-------- SlideshowResponse(from:)
(output returned to UI)      ^ Converts the Domain entity
```

The UseCase is responsible only for "translating input -> delegating to Domain -> translating output." The business logic ("how to create a slideshow") lives in the Domain Service. The UseCase is merely the bridge.
