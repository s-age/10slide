protocol PlaybackDomainServiceProtocol: Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int?
    func previousIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int?
    func applyConfig(_ config: SlideshowConfig, to slideshow: Slideshow) -> Slideshow
}
