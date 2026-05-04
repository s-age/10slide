import Foundation

final class UpdateSlideshowUseCase: UpdateSlideshowUseCaseProtocol {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(slideshow: Slideshow, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        let slideDuration = slideshow.config.duration.seconds ?? 0
        let slides = localIdentifiers.enumerated().map { index, id in
            Slide(id: UUID(), localIdentifier: id, order: index, duration: slideDuration, title: nil)
        }
        var updated = slideshow
        updated.name = name
        updated.slides = slides
        try await slideshowRepository.save(updated)
        return updated
    }
}
