import SwiftData
import Foundation

final class SlideDataSource: SlideDataSourceProtocol {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [SlideModel] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<SlideModel>())
    }

    func save(_ model: SlideModel) async throws {
        let context = ModelContext(container)
        context.insert(model)
        try context.save()
    }

    func delete(id: UUID) async throws {
        let context = ModelContext(container)
        try context.delete(model: SlideModel.self, where: #Predicate { $0.id == id })
        try context.save()
    }
}
