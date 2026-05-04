import Foundation
import SwiftData

@ModelActor
actor SlideDataSource: SlideDataSourceProtocol {
    func fetchAll() throws -> [SlideDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideModel>())
        return models.map { model in
            SlideDTO(
                id: model.id,
                localIdentifier: model.localIdentifier,
                order: model.order,
                duration: model.duration,
                title: model.title
            )
        }
    }

    func save(_ dto: SlideDTO) throws {
        let model = SlideModel(
            id: dto.id,
            localIdentifier: dto.localIdentifier,
            order: dto.order,
            duration: dto.duration,
            title: dto.title
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func delete(id: UUID) throws {
        try modelContext.delete(model: SlideModel.self, where: #Predicate { $0.id == id })
        try modelContext.save()
    }
}
