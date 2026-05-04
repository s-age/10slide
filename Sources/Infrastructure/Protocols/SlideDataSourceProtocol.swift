import Foundation

protocol SlideDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideDTO]
    func save(_ dto: SlideDTO) async throws
    func delete(id: UUID) async throws
}
