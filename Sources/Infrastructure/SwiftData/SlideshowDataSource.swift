import Foundation
import SwiftData
import Synchronization

final class SlideshowDataSource: SlideshowDataSourceProtocol {
    private let sharedContext: Mutex<ModelContext>
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        sharedContext = Mutex(ModelContext(container))
    }

    func fetchAll() async throws -> [SlideshowModel] {
        try sharedContext.withLock { ctx in
            try ctx.fetch(FetchDescriptor<SlideshowModel>())
        }
    }

    func fetch(id: UUID) async throws -> SlideshowModel? {
        try sharedContext.withLock { ctx in
            let descriptor = FetchDescriptor<SlideshowModel>(
                predicate: #Predicate { $0.id == id }
            )
            return try ctx.fetch(descriptor).first
        }
    }

    func save(_ model: SlideshowModel) async throws {
        // Swift 6: inserting a task-isolated @Model into an inout sending ModelContext
        // is a region isolation violation, so save uses a scoped context that writes
        // to the persistent store (visible to sharedContext on next fetch).
        let context = ModelContext(container)
        context.insert(model)
        try context.save()
    }

    func delete(id: UUID) async throws {
        try sharedContext.withLock { ctx in
            try ctx.delete(model: SlideshowModel.self, where: #Predicate { $0.id == id })
            try ctx.save()
        }
    }
}
