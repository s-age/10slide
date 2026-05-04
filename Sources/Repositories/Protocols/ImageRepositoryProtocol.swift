import Foundation

protocol ImageRepositoryProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImageData(localIdentifier: String) async throws -> Data
    func fetchThumbnailData(localIdentifier: String) async throws -> Data
}
