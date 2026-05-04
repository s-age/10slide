import Foundation

final class CreateSlideshowUseCase: CreateSlideshowUseCaseProtocol {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        let slideDuration = config.duration.seconds ?? 0
        let slides = localIdentifiers.enumerated().map { index, id in
            Slide(
                id: UUID(),
                localIdentifier: id,
                order: index,
                duration: slideDuration,
                title: nil
            )
        }
        let slideshow = Slideshow(
            id: UUID(),
            name: name,
            slides: slides,
            config: config,
            createdAt: Date()
        )
        try await slideshowRepository.save(slideshow)
        return slideshow
    }
}
