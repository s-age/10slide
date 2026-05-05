---
paths:
  - 'Sources/Presentation/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/Presentation/`:

- **Layer responsibility**: SwiftUI views own display. ViewModels connect use cases to views. `Presentation` is the only layer that may import `SwiftUI` or `UIKit`.
- **Import allowlist**: `SwiftUI`, `AppKit`, `Foundation`, `UseCases/Protocols`, `UseCases/Requests`, `UseCases/Responses` — never `Domain`, `Repositories`, `Infrastructure`, `SwiftData`, `Photos`.

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
    let viewModel: SlideshowListViewModel   // injected from DI; no @State needed

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
// Good — ViewModel is a thin bridge; uses Response types only
@Observable
final class SlideshowListViewModel {
    private(set) var slideshows: [SlideshowResponse] = []
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
            slideshows = try await fetchSlideshows.execute(FetchSlideshowsRequest())
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

## ViewModel storage: @State vs let vs @Bindable

`@State` means the **View owns and creates** the ViewModel. For ViewModels injected via `init`, use `let` or `@Bindable`.

| Situation | Correct storage |
|-----------|----------------|
| View creates the VM itself | `@State private var vm = MyVM(...)` |
| VM injected; no `$` binding needed | `let vm: MyVM` |
| VM injected; `$` binding needed (e.g. `TextField`) | `@Bindable var vm: MyVM` |

`@Observable` tracks property access automatically in `body` — `@State` is **not** required for observation to work.

```swift
// Good — injected VM, read-only access
struct SlideshowLibraryPanel: View {
    let viewModel: SlideshowLibraryViewModel

    init(viewModel: SlideshowLibraryViewModel) {
        self.viewModel = viewModel              // direct assignment
    }
}

// Good — injected VM, Binding needed
struct LibraryPickerView: View {
    @Bindable var createViewModel: CreateSlideshowViewModel

    init(createViewModel: CreateSlideshowViewModel) {
        self.createViewModel = createViewModel  // direct assignment
    }

    var body: some View {
        TextField("Name", text: $createViewModel.slideshowName)
    }
}

// Bad — State(initialValue:) for an injected VM
// Parent re-renders with a new instance → child silently keeps the old one
struct BadView: View {
    @State private var viewModel: MyViewModel

    init(viewModel: MyViewModel) {
        self._viewModel = State(initialValue: viewModel)  // NG
    }
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

- Never import `Domain/Entities`, `Domain/Services`, `Repositories`, `Infrastructure`, `SwiftData`, or `Photos` — route through use cases via Request/Response types
- Never add business logic in a View or ViewModel — extract to a use case
- Never use `Task {}` in `onAppear` when `.task` modifier can replace it
- Never hold more than one primary use case's output in a single ViewModel — split ViewModels instead
- Never put display formatting logic in a use case — formatting belongs here
- Never call a repository or domain service protocol method directly from a ViewModel
- Never use `State(initialValue:)` for an externally injected ViewModel — use `let` or `@Bindable var`
- Never use `.toDomain` computed properties — those are internal to the UseCase layer
