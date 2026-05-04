import Foundation

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let slideshowDataSource: any SlideshowDataSourceProtocol
    private let slideDataSource: any SlideDataSourceProtocol

    init(
        slideshowDataSource: any SlideshowDataSourceProtocol,
        slideDataSource: any SlideDataSourceProtocol
    ) {
        self.slideshowDataSource = slideshowDataSource
        self.slideDataSource = slideDataSource
    }

    func fetchAll() async throws -> [Slideshow] {
        let models = try await slideshowDataSource.fetchAll()
        return models.map(slideshow(from:))
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        guard let model = try await slideshowDataSource.fetch(id: id) else { return nil }
        return slideshow(from: model)
    }

    func save(_ slideshow: Slideshow) async throws {
        let model = SlideshowModel(
            id: slideshow.id,
            name: slideshow.name,
            createdAt: slideshow.createdAt,
            durationRawValue: slideshow.config.duration.rawValue,
            transitionRawValue: slideshow.config.transition.rawValue,
            loop: slideshow.config.loop
        )
        model.slides = slideshow.slides.map { slide in
            SlideModel(
                id: slide.id,
                localIdentifier: slide.localIdentifier,
                order: slide.order,
                duration: slide.duration,
                title: slide.title
            )
        }
        try await slideshowDataSource.save(model)
    }

    func delete(id: UUID) async throws {
        try await slideshowDataSource.delete(id: id)
    }

    // MARK: - Private

    private func slideshow(from model: SlideshowModel) -> Slideshow {
        let config = SlideshowConfig(
            duration: SlideDuration(rawValue: model.durationRawValue) ?? .five,
            transition: TransitionType(rawValue: model.transitionRawValue) ?? .default,
            loop: model.loop
        )
        let slides = model.slides
            .sorted { $0.order < $1.order }
            .map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, order: $0.order, duration: $0.duration, title: $0.title) }
        return Slideshow(id: model.id, name: model.name, slides: slides, config: config, createdAt: model.createdAt)
    }
}
