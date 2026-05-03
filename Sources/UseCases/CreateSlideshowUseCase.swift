import Foundation

final class CreateSlideshowUseCase: CreateSlideshowUseCaseProtocol {
    private let slideshowRepository: any SlideshowRepositoryProtocol
    private let configRepository: any ConfigRepositoryProtocol

    init(
        slideshowRepository: any SlideshowRepositoryProtocol,
        configRepository: any ConfigRepositoryProtocol
    ) {
        self.slideshowRepository = slideshowRepository
        self.configRepository = configRepository
    }

    func execute(name: String, localIdentifiers: [String]) async throws -> Slideshow {
        let config = try await configRepository.load()
        let slides = localIdentifiers.enumerated().map { index, id in
            Slide(
                id: UUID(),
                localIdentifier: id,
                order: index,
                duration: config.defaultDuration,
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
