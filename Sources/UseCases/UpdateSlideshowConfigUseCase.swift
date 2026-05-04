import Foundation

final class UpdateSlideshowConfigUseCase: UpdateSlideshowConfigUseCaseProtocol, Sendable {
    func execute(slideshow: Slideshow, config: SlideshowConfig) -> Slideshow {
        slideshow.applying(config: config)
    }
}
