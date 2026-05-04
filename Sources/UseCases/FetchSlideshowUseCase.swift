import Foundation

final class FetchSlideshowUseCase: FetchSlideshowUseCaseProtocol, Sendable {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(id: UUID) async throws -> Slideshow? {
        try await slideshowRepository.fetch(id: id)
    }
}
