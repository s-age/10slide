protocol FetchSlideshowsUseCaseProtocol: Sendable {
    func execute() async throws -> [Slideshow]
}
