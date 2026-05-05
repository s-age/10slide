import Foundation

final class PlaybackDomainService: PlaybackDomainServiceProtocol, Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex < totalSlides - 1 { return currentIndex + 1 }
        return loop ? 0 : nil
    }

    func previousIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex > 0 { return currentIndex - 1 }
        return loop ? totalSlides - 1 : nil
    }

    func applyConfig(_ config: SlideshowConfig, to slideshow: Slideshow) -> Slideshow {
        slideshow.applying(config: config)
    }
}
