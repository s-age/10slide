import Foundation

protocol ImageDataSourceProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImage(localIdentifier: String) async throws -> ImageDTO
    func fetchThumbnail(localIdentifier: String) async throws -> Data
    func setDirectory(_ url: URL)
    var supportedExtensions: Set<String> { get }
}

extension ImageDataSourceProtocol {
    func setDirectory(_ url: URL) {}
    var supportedExtensions: Set<String> { [] }
}
