import Foundation

protocol ImageDataSourceProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImage(localIdentifier: String) async throws -> ImageDTO
    func fetchThumbnail(localIdentifier: String) async throws -> Data
}
