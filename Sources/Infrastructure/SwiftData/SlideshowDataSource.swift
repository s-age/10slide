import Foundation
import SwiftData

@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))
    }

    func fetch(id: UUID) throws -> SlideshowDTO? {
        let descriptor = FetchDescriptor<SlideshowModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first.map(dto(from:))
    }

    func save(_ dto: SlideshowDTO) throws {
        let model = SlideshowModel(
            id: dto.id,
            name: dto.name,
            createdAt: dto.createdAt,
            durationRawValue: dto.durationRawValue,
            transitionRawValue: dto.transitionRawValue,
            loop: dto.loop
        )
        modelContext.insert(model)
        let slideModels = dto.slides.map { slide in
            SlideModel(
                id: slide.id,
                localIdentifier: slide.localIdentifier,
                order: slide.order,
                duration: slide.duration,
                title: slide.title
            )
        }
        slideModels.forEach { modelContext.insert($0) }
        model.slides = slideModels
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        try modelContext.delete(model: SlideshowModel.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }

    // MARK: - Private

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        SlideshowDTO(
            id: model.id,
            name: model.name,
            createdAt: model.createdAt,
            durationRawValue: model.durationRawValue,
            transitionRawValue: model.transitionRawValue,
            loop: model.loop,
            slides: model.slides.map { slide in
                SlideDTO(
                    id: slide.id,
                    localIdentifier: slide.localIdentifier,
                    order: slide.order,
                    duration: slide.duration,
                    title: slide.title
                )
            }
        )
    }
}
