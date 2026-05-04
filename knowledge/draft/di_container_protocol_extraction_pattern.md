---
name: DI container protocol extraction pattern
description: Sub-containers eagerly extract protocol properties from upstream containers, then discard the reference to prevent cross-container coupling
type: reference
---

## Pattern

In the 10slide DI architecture, sub-containers follow a strict pattern to prevent cross-layer coupling:

1. **Accept upstream container as init parameter** (not stored)
2. **Extract protocol-typed properties eagerly during init**
3. **Discard the container reference** after extraction

## Example: PresentationContainer

```swift
final class PresentationContainer {
    // ✓ Store extracted properties as protocol types
    private let fetchLibrary: any FetchLibraryUseCaseProtocol
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol

    // ✓ Accept upstream container as parameter (do NOT store it)
    init(useCases: UseCaseContainer) {
        fetchLibrary = useCases.fetchLibrary
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        // useCases reference is discarded here
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        // ✓ Use local properties, not useCases.fetchLibrary
        LibraryPickerViewModel(fetchLibrary: fetchLibrary)
    }
}
```

**Why:** Only `Container.swift` knows all layers. Sub-containers holding references to other sub-containers creates hidden coupling and violates the layered architecture.

## Contrast: What NOT to do

```swift
final class PresentationContainer {
    // ✗ Don't store the upstream container
    private let useCases: UseCaseContainer

    init(useCases: UseCaseContainer) {
        self.useCases = useCases  // ✗ Violation
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        // ✗ Lazy access through stored container
        LibraryPickerViewModel(fetchLibrary: useCases.fetchLibrary)
    }
}
```

This creates a persistent reference that couples PresentationContainer to UseCaseContainer structure.
