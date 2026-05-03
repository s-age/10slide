import Foundation

final class SlideRepository: SlideRepositoryProtocol {
    private let slideDataSource: any SlideDataSourceProtocol
    private let imageDataSource: any ImageDataSourceProtocol

    init(slideDataSource: any SlideDataSourceProtocol, imageDataSource: any ImageDataSourceProtocol) {
        self.slideDataSource = slideDataSource
        self.imageDataSource = imageDataSource
    }

    func fetchAll() async throws -> [Slide] {
        let models = try await slideDataSource.fetchAll()
        return models.map { model in
            Slide(
                id: model.id,
                localIdentifier: model.localIdentifier,
                order: model.order,
                duration: model.duration,
                title: model.title
            )
        }
    }

    func save(_ slide: Slide, in slideshowID: UUID) async throws {
        let model = SlideModel(
            id: slide.id,
            localIdentifier: slide.localIdentifier,
            order: slide.order,
            duration: slide.duration,
            title: slide.title
        )
        try await slideDataSource.save(model)
    }

    func delete(id: UUID) async throws {
        try await slideDataSource.delete(id: id)
    }
}
