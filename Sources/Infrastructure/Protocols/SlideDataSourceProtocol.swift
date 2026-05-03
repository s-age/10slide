import Foundation

protocol SlideDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideModel]
    func save(_ model: SlideModel) async throws
    func delete(id: UUID) async throws
}
