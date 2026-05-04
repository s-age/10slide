import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private(set) var slideshow: Slideshow
    private(set) var currentIndex: Int = 0
    private(set) var currentImage: NSImage?
    private(set) var isPlaying: Bool = false
    private(set) var showFilmstrip: Bool = true

    private let loadSlideImageUseCase: any LoadSlideImageUseCaseProtocol
    private let filmstripHideDuration: Duration
    private let imageDecoder: @Sendable (Data) -> NSImage?
    private var timerTask: Task<Void, Never>?
    private var hideFilmstripTask: Task<Void, Never>?

    init(
        slideshow: Slideshow,
        loadSlideImage: any LoadSlideImageUseCaseProtocol,
        filmstripHideDuration: Duration = .seconds(3),
        imageDecoder: @escaping @Sendable (Data) -> NSImage? = { NSImage(data: $0) }
    ) {
        self.slideshow = slideshow
        self.loadSlideImageUseCase = loadSlideImage
        self.filmstripHideDuration = filmstripHideDuration
        self.imageDecoder = imageDecoder
    }

    private var currentSlide: Slide? {
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
        let count = slideshow.slides.count
        guard count > 0 else { return }
        if currentIndex < count - 1 {
            currentIndex += 1
            await loadCurrentImage()
        } else if slideshow.config.loop {
            currentIndex = 0
            await loadCurrentImage()
        } else {
            pause()
        }
    }

    func previous() async {
        let count = slideshow.slides.count
        guard count > 0 else { return }
        if currentIndex > 0 {
            currentIndex -= 1
        } else if slideshow.config.loop {
            currentIndex = count - 1
        }
        await loadCurrentImage()
    }

    func jumpTo(index: Int) async {
        guard index >= 0, index < slideshow.slides.count else { return }
        currentIndex = index
        await loadCurrentImage()
    }

    func loadCurrentImage() async {
        guard let slide = currentSlide else {
            currentImage = nil
            return
        }
        do {
            let data = try await loadSlideImageUseCase.execute(localIdentifier: slide.localIdentifier)
            let decode = imageDecoder
            currentImage = await Task.detached(priority: .userInitiated) {
                decode(data)
            }.value
        } catch {
            currentImage = nil
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
