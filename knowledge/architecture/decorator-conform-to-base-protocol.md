---
type: gotcha
context: Decorators and concrete use cases that need to conform to UseCase protocol typealiases
keywords: [decorator, protocol, typealias, existential, AsyncUseCase, conformance, generics, where]
---

## What

UseCase protocol typealiases alias over generic base protocols (`AsyncUseCase<Req, Res>`). Swift existential types (`any Protocol`) are boxes — you can store values in them but cannot conform to them. Attempting to conform a class to a typealias of an existential is a compiler error.

The codebase intentionally uses a two-tier system:
- **Base protocol** (`AsyncUseCase`, `SyncUseCase`) — for conformance declarations
- **Typealias** (`CreateSlideshowUseCaseProtocol`) — for type annotations only (properties, parameters, return types)

## Do

Conform decorators and concrete use cases to the base protocol, constraining associated types via `where`:

```swift
final class ValidationAsyncUseCaseDecorator<
    Request: UseCaseRequest, Response, U: AsyncUseCase
>: AsyncUseCase, Sendable where U.Request == Request, U.Response == Response {
    func execute(_ request: Request) async throws -> Response { ... }
}
```

Use typealiases only at annotation sites (stored properties, init parameters, return types).

## Don't

Attempt to conform a class to a typealias of an existential:

```swift
// Compiler error — cannot conform to existential type
final class Decorator: CreateSlideshowUseCaseProtocol { ... }
```
