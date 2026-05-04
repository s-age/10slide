import Foundation

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let slideshowDataSource: any SlideshowDataSourceProtocol

    init(slideshowDataSource: any SlideshowDataSourceProtocol) {
        self.slideshowDataSource = slideshowDataSource
    }

    func fetchAll() async throws -> [Slideshow] {
        let dtos = try await slideshowDataSource.fetchAll()
        return dtos.map(slideshow(from:))
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        guard let dto = try await slideshowDataSource.fetch(id: id) else { return nil }
        return slideshow(from: dto)
    }

    func save(_ slideshow: Slideshow) async throws {
        let dto = SlideshowDTO(
            id: slideshow.id,
            name: slideshow.name,
            createdAt: slideshow.createdAt,
            durationRawValue: slideshow.config.duration.rawValue,
            transitionRawValue: slideshow.config.transition.rawValue,
            loop: slideshow.config.loop,
            slides: slideshow.slides.map { slide in
                SlideDTO(
                    id: slide.id,
                    localIdentifier: slide.localIdentifier,
                    order: slide.order,
                    duration: slide.duration,
                    title: slide.title
                )
            }
        )
        try await slideshowDataSource.save(dto)
    }

    func delete(id: UUID) async throws {
        try await slideshowDataSource.delete(id: id)
    }

    // MARK: - Private

    private func slideshow(from dto: SlideshowDTO) -> Slideshow {
        let config = SlideshowConfig(
            duration: SlideDuration(rawValue: dto.durationRawValue) ?? .five,
            transition: TransitionType(rawValue: dto.transitionRawValue) ?? .default,
            loop: dto.loop
        )
        let slides = dto.slides
            .sorted { $0.order < $1.order }
            .map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, order: $0.order, duration: $0.duration, title: $0.title) }
        return Slideshow(id: dto.id, name: dto.name, slides: slides, config: config, createdAt: dto.createdAt)
    }
}
