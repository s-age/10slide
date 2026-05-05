---
type: gotcha
context: UseCase protocol typealiases that embed `any` — do not add `any` again at use sites
keywords: [typealias, existential, any, UseCase, protocol, Swift]
---

## What

UseCase protocol typealiases embed `any` inside the definition:

```swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>
```

At use sites (DI container properties, ViewModel init parameters), adding `any` again produces a compiler error: `redundant 'any' in type`. The instinct to write `any Protocol` is correct for raw protocols, but breaks when the typealias already resolves to an existential.

## Do

Use the typealias directly, without an `any` prefix:

```swift
let createSlideshow: CreateSlideshowUseCaseProtocol
```

Conform concrete classes and decorators to the **base protocol** (`AsyncUseCase`), not the typealias — Swift does not allow conformance to an existential type.

## Don't

Add `any` at the use site when the typealias already resolves to an existential:

```swift
// Compiler error: redundant 'any'
let createSlideshow: any CreateSlideshowUseCaseProtocol
```

Do not attempt to conform a class directly to a typealias alias of an existential — that is also a compiler error.
