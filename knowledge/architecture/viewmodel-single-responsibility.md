---
type: decision
context: when a ViewModel accumulates outputs from multiple independent use cases
keywords: [ViewModel, single-responsibility, use case, split, coupling, testability, arch-presentation]
---

## What

A ViewModel that holds outputs from two or more independent use cases violates single
responsibility and hides real dependencies. Each ViewModel should own outputs from one
primary use case.

### Violation: combined ViewModel

```swift
@Observable @MainActor
final class LibraryPickerViewModel {
    var identifiers: [String] = []        // from FetchLibraryUseCase
    var thumbnails: [String: Data] = [:]  // from LoadThumbnailUseCase
    var currentDirectoryName: String = "" // from SetDirectoryUseCase

    func loadLibrary() async { ... }
    func loadThumbnail(identifier:) async { ... }
    func setDirectory(_:) async { ... }
}
```

A View that only needs identifiers is forced to accept thumbnail state and its use cases.

## Do

Split by primary output — one ViewModel per primary use case:

```swift
// Primary output: identifiers
@Observable @MainActor
final class LibraryViewModel {
    var identifiers: [String] = []
    var currentDirectoryName: String = ""

    func loadLibrary() async { ... }
    func setDirectory(_:) async { ... }
    func addDroppedFiles(_:) { ... }
}

// Primary output: thumbnails
@Observable @MainActor
final class ThumbnailViewModel {
    var thumbnails: [String: Data] = [:]

    func loadThumbnail(identifier:) async { ... }
}
```

A View that needs both takes separate `@State` instances:

```swift
@State private var libraryViewModel: LibraryViewModel
@State private var thumbnailViewModel: ThumbnailViewModel
```

Benefits: each ViewModel is testable against a single use case; `ThumbnailViewModel` is
reusable in any context that needs cached thumbnails; DI wiring shows exact dependencies.

## Don't

- Don't combine unrelated use-case outputs into one ViewModel
- Don't judge responsibility by whether methods share a screen — judge by primary output
- Don't merge ViewModels purely to reduce the number of `@State` properties in a View
