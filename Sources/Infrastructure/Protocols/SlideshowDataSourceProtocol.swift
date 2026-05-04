import Foundation

protocol SlideshowDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideshowDTO]
    func fetch(id: UUID) async throws -> SlideshowDTO?
    func save(_ dto: SlideshowDTO) async throws
    func delete(id: UUID) async throws
}
