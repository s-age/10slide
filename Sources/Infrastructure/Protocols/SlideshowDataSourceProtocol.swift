import Foundation

protocol SlideshowDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideshowModel]
    func fetch(id: UUID) async throws -> SlideshowModel?
    func save(_ model: SlideshowModel) async throws
    func delete(id: UUID) async throws
}
