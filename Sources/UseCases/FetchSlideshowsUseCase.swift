final class FetchSlideshowsUseCase: FetchSlideshowsUseCaseProtocol {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute() async throws -> [Slideshow] {
        try await slideshowRepository.fetchAll()
    }
}
