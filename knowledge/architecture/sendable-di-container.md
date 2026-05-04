---
type: gotcha
context: Passing DI container method references as @Sendable closures under Swift 6 strict concurrency
keywords: [Sendable, DI, container, Swift6, concurrency, factory-closure, final-class, MainActor]
---

## What

Under Swift 6 strict concurrency, passing a method from a non-`Sendable` object as a `@Sendable` closure triggers a warning:

```
warning: converting non-Sendable function value to
'@MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel' may introduce data races
```

This surfaced in `ContentView`, which stored factory closures typed as `@MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel` populated from `PresentationContainer` method references. Because `PresentationContainer` was not `Sendable`, the conversion was flagged.

## Do

Declare the DI container `final class` with only `let` stored properties, where each stored protocol type itself conforms to `Sendable`. A `final class` with only immutable `Sendable` stored properties satisfies `Sendable` without `@unchecked`.

```swift
final class PresentationContainer: Sendable {
    private let createSlideshow: any CreateSlideshowUseCaseProtocol  // Sendable
    // …
}
```

Once the container is `Sendable`, its method references pass as `@Sendable` closures cleanly.

Add `Sendable` to the container first; suppress warnings at the call site only as a last resort.

## Don't

- Don't suppress concurrency warnings at call sites with `@unchecked Sendable` or `nonisolated(unsafe)` when making the container properly `Sendable` is possible.
- Don't store `var` mutable properties in a DI container declared `Sendable` — the compiler will reject it.
