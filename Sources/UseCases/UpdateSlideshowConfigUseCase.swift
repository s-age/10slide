import Foundation

final class UpdateSlideshowConfigUseCase: UpdateSlideshowConfigUseCaseProtocol {
    func execute(slideshow: Slideshow, config: SlideshowConfig) -> Slideshow {
        var updated = slideshow
        updated.config = config
        return updated
    }
}
