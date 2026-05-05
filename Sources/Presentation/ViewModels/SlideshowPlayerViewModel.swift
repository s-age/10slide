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
    private(set) var errorMessage: String?

    private let loadSlideImageUseCase: LoadSlideImageUseCaseProtocol
    private let updateSlideshowConfigUseCase: UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlideUseCase: AdvanceSlideUseCaseProtocol
    private let previousSlideUseCase: PreviousSlideUseCaseProtocol
    private let filmstripHideDuration: Duration
    private var timerTask: Task<Void, Never>?
    private var hideFilmstripTask: Task<Void, Never>?

    init(
        slideshow: SlideshowResponse,
        loadSlideImage: LoadSlideImageUseCaseProtocol,
        updateSlideshowConfig: UpdateSlideshowConfigUseCaseProtocol,
        advanceSlide: AdvanceSlideUseCaseProtocol,
        previousSlide: PreviousSlideUseCaseProtocol,
        filmstripHideDuration: Duration = .seconds(3)
    ) {
        self.slideshow = slideshow
        self.loadSlideImageUseCase = loadSlideImage
        self.updateSlideshowConfigUseCase = updateSlideshowConfig
        self.advanceSlideUseCase = advanceSlide
        self.previousSlideUseCase = previousSlide
        self.filmstripHideDuration = filmstripHideDuration
    }

    private var currentSlide: SlideResponse? {
        guard !slideshow.slides.isEmpty, currentIndex < slideshow.slides.count else { return nil }
        return slideshow.slides[currentIndex]
    }

    // MARK: - Playback

    func play() {
        guard !slideshow.slides.isEmpty else { return }
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
        if let prevIndex = try? previousSlideUseCase.execute(request) {
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

    // MARK: - Config mutation

    func updateDuration(_ duration: SlideDurationResponse) async {
        let request = UpdateSlideshowConfigRequest(
            slideshowID: slideshow.id,
            duration: duration,
            transition: slideshow.config.transition,
            loop: slideshow.config.loop
        )
        do {
            slideshow = try await updateSlideshowConfigUseCase.execute(request)
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
            slideshow = try await updateSlideshowConfigUseCase.execute(request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Filmstrip visibility

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
