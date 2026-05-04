import Foundation
import SwiftData

final class SlideRepository: SlideRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    init(store: any SwiftDataStoreProtocol) {
        self.store = store
    }

    func fetchAll() async throws -> [Slide] {
        try await store.fetch(FetchDescriptor<SlideModel>()) {
            Slide(id: $0.id, localIdentifier: $0.localIdentifier, order: $0.order, duration: $0.duration, title: $0.title)
        }
    }

    func save(_ slide: Slide, in slideshowID: UUID) async throws {
        let id = slide.id
        let localIdentifier = slide.localIdentifier
        let order = slide.order
        let duration = slide.duration
        let title = slide.title
        try await store.write { context in
            let model = SlideModel(
                id: id,
                localIdentifier: localIdentifier,
                order: order,
                duration: duration,
                title: title
            )
            context.insert(model)
            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await store.delete(SlideModel.self, where: #Predicate { $0.id == id })
    }
}
