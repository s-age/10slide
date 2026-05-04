import Foundation
import SwiftData

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    init(store: any SwiftDataStoreProtocol) {
        self.store = store
    }

    func fetchAll() async throws -> [Slideshow] {
        try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await store.fetch(
            FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        ) { [self] in slideshow(from: $0) }.first
    }

    func save(_ slideshow: Slideshow) async throws {
        let id = slideshow.id
        let name = slideshow.name
        let createdAt = slideshow.createdAt
        let durationRawValue = slideshow.config.duration.rawValue
        let transitionRawValue = slideshow.config.transition.rawValue
        let loop = slideshow.config.loop
        let slides = slideshow.slides

        try await store.write { context in
            let newSlides = slides.map {
                SlideModel(
                    id: $0.id,
                    localIdentifier: $0.localIdentifier,
                    order: $0.order,
                    duration: $0.duration,
                    title: $0.title
                )
            }
            let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.durationRawValue = durationRawValue
                existing.transitionRawValue = transitionRawValue
                existing.loop = loop
                existing.slides.forEach { context.delete($0) }
                newSlides.forEach { context.insert($0) }
                existing.slides = newSlides
            } else {
                let model = SlideshowModel(
                    id: id,
                    name: name,
                    createdAt: createdAt,
                    durationRawValue: durationRawValue,
                    transitionRawValue: transitionRawValue,
                    loop: loop
                )
                context.insert(model)
                newSlides.forEach { context.insert($0) }
                model.slides = newSlides
            }
            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
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
