import Foundation

final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    private let repository: any SlideshowRepositoryProtocol

    init(repository: any SlideshowRepositoryProtocol) {
        self.repository = repository
    }

    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        let slideshow = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
        try await repository.save(slideshow)
        return slideshow
    }

    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
        try await repository.save(updated)
        return updated
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await repository.fetch(id: id)
    }

    func fetchAll() async throws -> [Slideshow] {
        try await repository.fetchAll()
    }
}
