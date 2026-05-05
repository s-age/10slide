# Presentation Layer (refactored)

All ViewModels stop importing Domain/Entities and use Response types exclusively.

**Import allowlist (updated)**: `SwiftUI`, `AppKit`, `Foundation`, `UseCases/Protocols`, `UseCases/Requests`, `UseCases/Responses` — never `Domain`, `Repositories`, `Infrastructure`.

---

## `Sources/Presentation/ViewModels/SlideshowLibraryViewModel.swift` (modified)

Key changes:
- `slideshows: [Slideshow]` → `slideshows: [SlideshowResponse]`
- UseCase calls pass Request structs

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SlideshowLibraryViewModel {
    private(set) var slideshows: [SlideshowResponse] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchSlideshowsUseCase: any FetchSlideshowsUseCaseProtocol
    private let deleteSlideshowUseCase: any DeleteSlideshowUseCaseProtocol

    init(
        fetchSlideshows: any FetchSlideshowsUseCaseProtocol,
        deleteSlideshow: any DeleteSlideshowUseCaseProtocol
    ) {
        self.fetchSlideshowsUseCase = fetchSlideshows
        self.deleteSlideshowUseCase = deleteSlideshow
    }

    func loadLibrary() async {
        isLoading = true
        defer { isLoading = false }
        do {
            slideshows = try await fetchSlideshowsUseCase.execute(FetchSlideshowsRequest())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSlideshow(id: UUID) async {
        do {
            try await deleteSlideshowUseCase.execute(DeleteSlideshowRequest(id: id))
            slideshows.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## `Sources/Presentation/ViewModels/CreateSlideshowViewModel.swift` (modified)

Key changes:
- `editingSlideshow: Slideshow?` → `editingSlideshow: SlideshowResponse?`
- `saveSlideshow()` returns `SlideshowResponse?`
- Uses `SlideDurationResponse` and `TransitionTypeResponse` for picker state

```swift
import Foundation
import Observation

@Observable
@MainActor
final class CreateSlideshowViewModel {
    private(set) var selectedIdentifiers: [String] = []
    var slideshowName: String = ""
    var selectedDuration: SlideDurationResponse = .five
    var selectedTransition: TransitionTypeResponse = .fade
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var editingSlideshow: SlideshowResponse?

    private let createSlideshowUseCase: any CreateSlideshowUseCaseProtocol
    private let updateSlideshowUseCase: any UpdateSlideshowUseCaseProtocol
    private let addDroppedFilesUseCase: any AddDroppedFilesUseCaseProtocol

    init(
        createSlideshow: any CreateSlideshowUseCaseProtocol,
        updateSlideshow: any UpdateSlideshowUseCaseProtocol,
        addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    ) {
        self.createSlideshowUseCase = createSlideshow
        self.updateSlideshowUseCase = updateSlideshow
        self.addDroppedFilesUseCase = addDroppedFiles
    }

    var isEditing: Bool { editingSlideshow != nil }

    var hasUnsavedWork: Bool {
        !slideshowName.isEmpty || !selectedIdentifiers.isEmpty
    }

    func loadSlideshow(_ slideshow: SlideshowResponse) {
        editingSlideshow = slideshow
        slideshowName = slideshow.name
        selectedIdentifiers = slideshow.slides.map(\.localIdentifier)
    }

    func reset() {
        editingSlideshow = nil
        slideshowName = ""
        selectedIdentifiers = []
    }

    func addFiles(_ urls: [URL]) {
        let request = AddDroppedFilesRequest(
            urls: urls,
            existingIdentifiers: selectedIdentifiers
        )
        guard let newPaths = try? addDroppedFilesUseCase.execute(request) else { return }
        selectedIdentifiers.append(contentsOf: newPaths)
    }

    func removeFile(_ identifier: String) {
        selectedIdentifiers.removeAll { $0 == identifier }
    }

    func saveSlideshow() async -> SlideshowResponse? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let existing = editingSlideshow {
                let request = UpdateSlideshowRequest(
                    id: existing.id,
                    name: slideshowName,
                    localIdentifiers: selectedIdentifiers
                )
                return try await updateSlideshowUseCase.execute(request)
            } else {
                let request = CreateSlideshowRequest(
                    name: slideshowName,
                    localIdentifiers: selectedIdentifiers,
                    duration: selectedDuration,
                    transition: selectedTransition,
                    loop: true
                )
                return try await createSlideshowUseCase.execute(request)
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
```

---

## `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` (modified)

Key changes:
- `slideshow: Slideshow` → `slideshow: SlideshowResponse`
- `advanceSlideUseCase.execute(slideshow:currentIndex:)` → pass `AdvanceSlideRequest`
- `updateSlideshowConfigUseCase` takes `UpdateSlideshowConfigRequest`

```swift
import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private(set) var slideshow: SlideshowResponse
    private(set) var currentIndex: Int = 0
    private(set) var currentNSImage: NSImage?
    private(set) var isPlaying: Bool = false
    private(set) var showFilmstrip: Bool = true

    private let loadSlideImageUseCase: any LoadSlideImageUseCaseProtocol
    private let updateSlideshowConfigUseCase: any UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlideUseCase: any AdvanceSlideUseCaseProtocol
    private let filmstripHideDuration: Duration
    private var timerTask: Task<Void, Never>?
    private var hideFilmstripTask: Task<Void, Never>?

    init(
        slideshow: SlideshowResponse,
        loadSlideImage: any LoadSlideImageUseCaseProtocol,
        updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol,
        advanceSlide: any AdvanceSlideUseCaseProtocol,
        filmstripHideDuration: Duration = .seconds(3)
    ) {
        self.slideshow = slideshow
        self.loadSlideImageUseCase = loadSlideImage
        self.updateSlideshowConfigUseCase = updateSlideshowConfig
        self.advanceSlideUseCase = advanceSlide
        self.filmstripHideDuration = filmstripHideDuration
    }

    private var currentSlide: SlideResponse? {
        guard !slideshow.slides.isEmpty, currentIndex < slideshow.slides.count else { return nil }
        return slideshow.slides[currentIndex]
    }

    func play() {
        guard !slideshow.slides.isEmpty else { return }
        guard let duration = slideshow.config.duration.seconds else { return }
        isPlaying = true
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled, isPlaying {
                do {
                    try await Task.sleep(for: .seconds(duration))
                } catch { break }
                guard !Task.isCancelled, isPlaying else { break }
                await next()
            }
        }
        showFilmstripOverlay()
    }

    func pause() {
        isPlaying = false
        timerTask?.cancel()
        timerTask = nil
        hideFilmstripTask?.cancel()
        hideFilmstripTask = nil
        showFilmstrip = true
    }

    func next() async {
        let request = AdvanceSlideRequest(
            totalSlides: slideshow.slides.count,
            currentIndex: currentIndex,
            loop: slideshow.config.loop
        )
        if let nextIndex = try? advanceSlideUseCase.execute(request) {
            currentIndex = nextIndex
            await loadCurrentImage()
        } else {
            pause()
        }
    }

    func previous() async {
        let request = PreviousSlideRequest(
            totalSlides: slideshow.slides.count,
            currentIndex: currentIndex,
            loop: slideshow.config.loop
        )
        if let prevIndex = try? advanceSlideUseCase.executePrevious(request) {
            currentIndex = prevIndex
            await loadCurrentImage()
        }
    }

    func jumpTo(index: Int) async {
        guard index >= 0, index < slideshow.slides.count else { return }
        currentIndex = index
        await loadCurrentImage()
    }

    func loadCurrentImage() async {
        guard let slide = currentSlide else {
            currentNSImage = nil
            return
        }
        let expectedIndex = currentIndex
        do {
            let request = LoadSlideImageRequest(localIdentifier: slide.localIdentifier)
            let data = try await loadSlideImageUseCase.execute(request)
            guard currentIndex == expectedIndex else { return }
            let image = await Task.detached(priority: .userInitiated) {
                NSImage(data: data)
            }.value
            guard currentIndex == expectedIndex else { return }
            currentNSImage = image
        } catch {
            currentNSImage = nil
        }
    }

    func updateDuration(_ duration: SlideDurationResponse) async {
        let request = UpdateSlideshowConfigRequest(
            slideshowID: slideshow.id,
            duration: duration,
            transition: slideshow.config.transition,
            loop: slideshow.config.loop
        )
        if let updated = try? await updateSlideshowConfigUseCase.execute(request) {
            slideshow = updated
        }
        if isPlaying { play() }
    }

    func updateTransition(_ transition: TransitionTypeResponse) async {
        let request = UpdateSlideshowConfigRequest(
            slideshowID: slideshow.id,
            duration: slideshow.config.duration,
            transition: transition,
            loop: slideshow.config.loop
        )
        if let updated = try? await updateSlideshowConfigUseCase.execute(request) {
            slideshow = updated
        }
    }

    func userDidInteract() {
        showFilmstripOverlay()
    }

    func showFilmstripOverlay() {
        showFilmstrip = true
        hideFilmstripTask?.cancel()
        hideFilmstripTask = nil
        guard isPlaying else { return }
        hideFilmstripTask = Task {
            try? await Task.sleep(for: filmstripHideDuration)
            guard !Task.isCancelled else { return }
            showFilmstrip = false
        }
    }
}
```

---

## `Sources/Presentation/ViewModels/ThumbnailViewModel.swift` (no Entity changes needed)

This ViewModel already only uses `Data` and `NSImage` — no Domain entity references. The only change is the UseCase call signature:

```swift
func loadThumbnail(identifier: String) async {
    guard thumbnails[identifier] == nil else { return }
    let request = LoadThumbnailRequest(localIdentifier: identifier)
    guard let data = try? await loadThumbnailUseCase.execute(request) else { return }
    thumbnails[identifier] = data
    images[identifier] = await Task.detached(priority: .userInitiated) {
        NSImage(data: data)
    }.value
}
```

---

## `Sources/Presentation/Views/SlideDuration+Presentation.swift` (modified)

This file currently extends Domain's `SlideDuration`. It must be refactored to extend `SlideDurationResponse` instead:

```swift
import Foundation

extension SlideDurationResponse {
    var displayLabel: String {
        switch self {
        case .five: "5s"
        case .ten: "10s"
        case .fifteen: "15s"
        case .thirty: "30s"
        case .sixty: "60s"
        case .manual: "Manual"
        }
    }
}
```

---

## Views referencing `Slideshow` or `Slide` directly

All Views that currently accept `Slideshow` parameters must switch to `SlideshowResponse`. Affected files:
- `ContentView.swift` — navigation state type
- `HomeView.swift` — list item type
- `SlideshowPlayerView.swift` — player init parameter
- `SlideshowLibraryPanel.swift` — list data source
- `FilmstripView.swift` — slide list type
