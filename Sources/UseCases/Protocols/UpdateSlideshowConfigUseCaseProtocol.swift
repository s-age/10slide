import Foundation

protocol UpdateSlideshowConfigUseCaseProtocol: Sendable {
    func execute(slideshow: Slideshow, config: SlideshowConfig) -> Slideshow
}
