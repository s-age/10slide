import Foundation

final class SlideRepository: SlideRepositoryProtocol {
    private let slideDataSource: any SlideDataSourceProtocol
    private let imageDataSource: any ImageDataSourceProtocol

    init(slideDataSource: any SlideDataSourceProtocol, imageDataSource: any ImageDataSourceProtocol) {
        self.slideDataSource = slideDataSource
        self.imageDataSource = imageDataSource
    }

    func fetchAll() async throws -> [Slide] {
        let dtos = try await slideDataSource.fetchAll()
        return dtos.map { dto in
            Slide(
                id: dto.id,
                localIdentifier: dto.localIdentifier,
                order: dto.order,
                duration: dto.duration,
                title: dto.title
            )
        }
    }

    func save(_ slide: Slide, in slideshowID: UUID) async throws {
        let dto = SlideDTO(
            id: slide.id,
            localIdentifier: slide.localIdentifier,
            order: slide.order,
            duration: slide.duration,
            title: slide.title
        )
        try await slideDataSource.save(dto)
    }

    func delete(id: UUID) async throws {
        try await slideDataSource.delete(id: id)
    }
}
