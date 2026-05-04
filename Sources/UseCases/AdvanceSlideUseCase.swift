final class AdvanceSlideUseCase: AdvanceSlideUseCaseProtocol, Sendable {
    func execute(slideshow: Slideshow, currentIndex: Int) -> Int? {
        slideshow.nextSlideIndex(from: currentIndex)
    }

    func executePrevious(slideshow: Slideshow, currentIndex: Int) -> Int? {
        slideshow.previousSlideIndex(from: currentIndex)
    }
}
