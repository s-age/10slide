import Foundation

protocol SlideshowDomainServiceProtocol: Sendable {
    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow
    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow
    func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow
    func delete(id: UUID) async throws
    func fetch(id: UUID) async throws -> Slideshow?
    func fetchAll() async throws -> [Slideshow]
}
