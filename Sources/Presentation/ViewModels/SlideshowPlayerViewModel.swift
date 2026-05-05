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
    private(set) var isShuffled: Bool = false
    private var shuffledSlides: [SlideResponse]?

    var displayedSlides: [SlideResponse] {
        shuffledSlides ?? slideshow.slides
    }
    enum FullscreenHintType: Equatable {
        case enter
        case exit
    }

    private(set) var showFilmstrip: Bool = true
    private(set) var fullscreenHint: FullscreenHintType? = nil
    private(set) var errorMessage: String?

    private let loadSlideImage: LoadSlideImageUseCaseProtocol
    private let updateSlideshowConfig: UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlide: AdvanceSlideUseCaseProtocol
    private let previousSlide: PreviousSlideUseCaseProtocol
    private let filmstripHideDuration: Duration
    private var timerTask: Task<Void, Never>?
    private var hideFilmstripTask: Task<Void, Never>?
    private var hideHintTask: Task<Void, Never>?
    private var overlayHoverCount: Int = 0
    private var enterHintShown: Bool = false

    init(
        slideshow: SlideshowResponse,
        loadSlideImage: LoadSlideImageUseCaseProtocol,
        updateSlideshowConfig: UpdateSlideshowConfigUseCaseProtocol,
        advanceSlide: AdvanceSlideUseCaseProtocol,
        previousSlide: PreviousSlideUseCaseProtocol,
        filmstripHideDuration: Duration = .seconds(3)
    ) {
        self.slideshow = slideshow
        self.loadSlideImage = loadSlideImage
        self.updateSlideshowConfig = updateSlideshowConfig
        self.advanceSlide = advanceSlide
        self.previousSlide = previousSlide
        self.filmstripHideDuration = filmstripHideDuration
    }

    private var currentSlide: SlideResponse? {
        let slides = displayedSlides
        guard !slides.isEmpty, currentIndex < slides.count else { return nil }
        return slides[currentIndex]
    }

    // MARK: - Shuffle

    func toggleShuffle() async {
        if isShuffled {
            isShuffled = false
            shuffledSlides = nil
        } else {
            shuffledSlides = slideshow.slides.shuffled()
            isShuffled = true
        }
        currentIndex = 0
        await loadCurrentImage()
    }

    // MARK: - Playback

    func play() {
        guard !displayedSlides.isEmpty else { return }
        guard let duration = slideshow.config.duration.seconds else { return }
        isPlaying = true
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled, isPlaying {
                do {
                    try await Task.sleep(for: .seconds(duration))
                } catch {
                    break
                }
                guard !Task.isCancelled, isPlaying else { break }
                await next()
            }
        }
        if !enterHintShown {
            enterHintShown = true
            showHint(.enter)
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
            totalSlides: displayedSlides.count,
            currentIndex: currentIndex,
            loop: slideshow.config.loop
        )
        // Validation failure = programming bug (UI guards these states); nil = no more slides
        if let nextIndex = try? advanceSlide.execute(request) {
            currentIndex = nextIndex
            await loadCurrentImage()
        } else {
            pause()
        }
    }

    func previous() async {
        let request = PreviousSlideRequest(
            totalSlides: displayedSlides.count,
            currentIndex: currentIndex,
            loop: slideshow.config.loop
        )
        // Validation failure = programming bug (UI guards these states); nil = no more slides
        if let prevIndex = try? previousSlide.execute(request) {
            currentIndex = prevIndex
            await loadCurrentImage()
            showFilmstripOverlay()
        }
    }

    func jumpTo(index: Int) async {
        guard index >= 0, index < displayedSlides.count else { return }
        currentIndex = index
        await loadCurrentImage()
        showFilmstripOverlay()
    }

    func loadCurrentImage() async {
        guard let slide = currentSlide else {
            currentNSImage = nil
            return
        }
        let expectedIndex = currentIndex
        do {
            let request = LoadSlideImageRequest(localIdentifier: slide.localIdentifier)
            let data = try await loadSlideImage.execute(request)
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

    // MARK: - Config mutation

    func updateDuration(_ duration: SlideDurationResponse) async {
        let request = UpdateSlideshowConfigRequest(
            slideshowID: slideshow.id,
            duration: duration,
            transition: slideshow.config.transition,
            loop: slideshow.config.loop
        )
        do {
            slideshow = try await updateSlideshowConfig.execute(request)
        } catch {
            errorMessage = error.localizedDescription
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
        do {
            slideshow = try await updateSlideshowConfig.execute(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filmstrip visibility

    func userDidInteract() {
        showFilmstripOverlay()
    }

    func userDidNext() async {
        await next()
        showFilmstripOverlay()
    }

    func overlayHoverBegan() {
        overlayHoverCount += 1
        showFilmstrip = true
        hideFilmstripTask?.cancel()
        hideFilmstripTask = nil
    }

    func overlayHoverEnded() {
        overlayHoverCount = max(0, overlayHoverCount - 1)
        guard overlayHoverCount == 0, isPlaying else { return }
        scheduleHideFilmstrip()
    }

    func dismissError() {
        errorMessage = nil
    }

    func showFilmstripOverlay() {
        showFilmstrip = true
        hideFilmstripTask?.cancel()
        hideFilmstripTask = nil
        guard isPlaying, overlayHoverCount == 0 else { return }
        scheduleHideFilmstrip()
    }

    func windowDidEnterFullScreen() {
        showHint(.exit)
    }

    private func showHint(_ type: FullscreenHintType) {
        hideHintTask?.cancel()
        fullscreenHint = type
        hideHintTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            fullscreenHint = nil
        }
    }

    private func scheduleHideFilmstrip() {
        hideFilmstripTask = Task {
            try? await Task.sleep(for: filmstripHideDuration)
            guard !Task.isCancelled else { return }
            showFilmstrip = false
        }
    }
}
