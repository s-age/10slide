protocol AdvanceSlideUseCaseProtocol: Sendable {
    func execute(slideshow: Slideshow, currentIndex: Int) -> Int?
    func executePrevious(slideshow: Slideshow, currentIndex: Int) -> Int?
}
