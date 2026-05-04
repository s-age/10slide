import Foundation

final class UpdateSlideshowUseCase: UpdateSlideshowUseCaseProtocol, Sendable {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(slideshow: Slideshow, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        let updated = slideshow.updating(name: name, localIdentifiers: localIdentifiers)
        try await slideshowRepository.save(updated)
        return updated
    }
}
