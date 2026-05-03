import Foundation

protocol SlideRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slide]
    func save(_ slide: Slide, in slideshowID: UUID) async throws
    func delete(id: UUID) async throws
}
