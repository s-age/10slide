---
type: decision
context: when wiring a sub-container that depends on an upstream container
keywords: [DI, container, protocol, extraction, coupling, PresentationContainer, UseCaseContainer]
---

## What

Sub-containers must not store a reference to another sub-container. Only `Container.swift` knows
all layers. Storing cross-container references creates hidden coupling and violates the layered
architecture. The pattern: accept the upstream container as an `init` parameter, extract needed
properties as protocol types eagerly, then let the reference be deallocated.

See `Sources/DI/PresentationContainer.swift` and `Sources/DI/Container.swift`.

## Do

Extract protocol-typed properties during `init`, discard the container reference:

```swift
final class PresentationContainer {
    private let fetchLibrary: any FetchLibraryUseCaseProtocol
    private let createSlideshow: any CreateSlideshowUseCaseProtocol

    init(useCases: UseCaseContainer) {
        fetchLibrary = useCases.fetchLibrary        // extract
        createSlideshow = useCases.createSlideshow  // extract
        // useCases reference dropped here
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        LibraryPickerViewModel(fetchLibrary: fetchLibrary)
    }
}
```

## Don't

Don't store the upstream container as a property:

```swift
// ✗ Violation — creates persistent cross-layer coupling
final class PresentationContainer {
    private let useCases: UseCaseContainer   // ✗

    init(useCases: UseCaseContainer) {
        self.useCases = useCases   // ✗
    }
}
```

- Don't access `useCases.fetchLibrary` lazily from stored container — extract at init time.
- Don't let a sub-container import another sub-container's module or type directly.
