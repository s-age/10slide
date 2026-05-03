---
paths:
  - 'Sources/Presentation/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/Presentation/`:

- **Layer responsibility**: SwiftUI views own display. ViewModels connect use cases to views. `Presentation` is the only layer that may import `SwiftUI` or `UIKit`.
- **Import allowlist**: `SwiftUI`, `Foundation`, `Domain/Entities`, `UseCases/Protocols` — never `Repositories`, `Infrastructure`, `SwiftData`, `Photos`.

## Directory layout

```
Presentation/
├── Views/         # SwiftUI View types
└── ViewModels/    # @Observable classes; one per screen
```

## .task modifier

Prefer the `.task` view modifier over `Task {}` inside `onAppear` or `init`. The `.task` modifier is automatically cancelled when the view disappears, preventing resource leaks.

```swift
// Good — .task is tied to view lifecycle and auto-cancelled
struct SlideshowListView: View {
    @State private var viewModel: SlideshowListViewModel

    var body: some View {
        List(viewModel.slideshows) { slideshow in
            Text(slideshow.name)
        }
        .task { await viewModel.load() }
    }
}

// Bad — Task{} in onAppear leaks if the view disappears before completion
struct SlideshowListView: View {
    var body: some View {
        List(...) { ... }
            .onAppear {
                Task { await viewModel.load() }   // NG: not cancelled on disappear
            }
    }
}
```

For tasks that depend on a value changing, use `.task(id:)`:

```swift
.task(id: selectedID) {
    await viewModel.loadDetail(id: selectedID)
}
```

## ViewModel — thin adapter between use cases and views

A ViewModel is a **lifecycle adapter**, not a logic container. Keep business logic in use cases; keep display formatting in the ViewModel.

```swift
// Good — ViewModel is a thin bridge
@Observable
final class SlideshowListViewModel {
    private(set) var slideshows: [Slideshow] = []
    private(set) var isLoading = false
    private let fetchSlideshows: any FetchSlideshowsUseCaseProtocol

    init(fetchSlideshows: any FetchSlideshowsUseCaseProtocol) {
        self.fetchSlideshows = fetchSlideshows
    }

    @MainActor
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            slideshows = try await fetchSlideshows.execute()
        } catch {
            // handle error state
        }
    }
}

// Bad — ViewModel holds a repository directly, bypassing the use case layer
@Observable
final class SlideshowListViewModel {
    private let repository: any SlideRepositoryProtocol   // NG: always use use cases
}
```

## @Observable vs ObservableObject

Prefer `@Observable` (Swift 5.9+). Use `ObservableObject` only when the deployment target requires it.

## Mutex for ViewModel shared state

If a ViewModel property is read from the main actor but written from a background task, use `Mutex` to synchronize access rather than adding `@unchecked Sendable`.

```swift
import Synchronization

@Observable
final class ImageLoadingViewModel {
    private let cache: Mutex<[String: UIImage]> = Mutex([:])

    func cachedImage(for id: String) -> UIImage? {
        cache.withLock { $0[id] }
    }

    func store(_ image: UIImage, for id: String) {
        cache.withLock { $0[id] = image }
    }
}
```

## Prohibitions

- Never import `Repositories`, `Infrastructure`, `SwiftData`, or `Photos` — route through use cases
- Never add business logic in a View or ViewModel — extract to a use case
- Never use `Task {}` in `onAppear` when `.task` modifier can replace it
- Never hold more than one primary use case's output in a single ViewModel — split ViewModels instead
- Never put display formatting logic in a use case — formatting belongs here
- Never call a repository protocol method directly from a ViewModel
