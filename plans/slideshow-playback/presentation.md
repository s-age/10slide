# Presentation Layer

## `Sources/Presentation/ViewModels/LibraryPickerViewModel.swift` (new)

```swift
import Foundation
import Observation

@Observable
@MainActor
final class LibraryPickerViewModel {
    private(set) var identifiers: [String] = []
    var selectedIdentifiers: Set<String> = []
    var slideshowName: String = ""
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchLibrary: FetchLibraryUseCase
    private let createSlideshow: CreateSlideshowUseCase

    init(
        fetchLibrary: FetchLibraryUseCase,
        createSlideshow: CreateSlideshowUseCase
    ) {
        self.fetchLibrary = fetchLibrary
        self.createSlideshow = createSlideshow
    }

    func loadLibrary() async { ... }
    func createSlideshow() async -> Slideshow? { ... }
}
```

## `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` (new)

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private(set) var slideshow: Slideshow
    private(set) var currentIndex: Int = 0
    private(set) var currentImageData: Data?
    private(set) var isPlaying: Bool = false
    private(set) var showFilmstrip: Bool = true

    private let loadSlideImage: LoadSlideImageUseCase
    private var timerTask: Task<Void, Never>?
    private var hideFilmstripTask: Task<Void, Never>?

    init(slideshow: Slideshow, loadSlideImage: LoadSlideImageUseCase) {
        self.slideshow = slideshow
        self.loadSlideImage = loadSlideImage
    }

    func play() { ... }
    func pause() { ... }
    func jumpTo(index: Int) async { ... }
    func next() async { ... }
    func previous() async { ... }
    func loadCurrentImage() async { ... }
    func userDidInteract() { ... }
    func showFilmstripOverlay() { ... }
}
```

Playback timer spec:
1. `play()` → `isPlaying = true`, start Task sleeping for `currentSlide.duration`
2. On wake → call `next()`, loop if `slideshow.config.loop`
3. `pause()` or view disappear → `timerTask.cancel()`

Filmstrip visibility spec:
1. Initial: visible
2. 3 seconds idle during playback → animate hide
3. Tap / hover → show + reset timer
4. Paused → always visible

## `Sources/Presentation/Views/LibraryPickerView.swift` (new)

```swift
import SwiftUI

struct LibraryPickerView: View {
    @State private var viewModel: LibraryPickerViewModel
    var onSlideshowCreated: (Slideshow) -> Void

    init(viewModel: LibraryPickerViewModel, onSlideshowCreated: @escaping (Slideshow) -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSlideshowCreated = onSlideshowCreated
    }

    var body: some View {
        // Grid of photo thumbnails with selection
        // "Create" button calling createSlideshow()
        ...
    }
}
```

## `Sources/Presentation/Views/SlideshowPlayerView.swift` (new)

```swift
import SwiftUI

struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel

    init(viewModel: SlideshowPlayerViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Full-screen current slide image
            // Transition based on slideshow.config.transition
            // FilmstripView overlay at bottom
        }
        .onTapGesture { viewModel.userDidInteract() }
    }
}
```

## `Sources/Presentation/Views/FilmstripView.swift` (new)

```swift
import SwiftUI

struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        // Horizontal ScrollView of square thumbnails
        // Highlight border on currentIndex
        // Tap calls onSelect(index)
        ...
    }
}
```
