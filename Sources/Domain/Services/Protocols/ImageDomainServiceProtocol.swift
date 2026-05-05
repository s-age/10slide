import Foundation

protocol ImageDomainServiceProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImageData(localIdentifier: String) async throws -> Data
    func fetchThumbnailData(localIdentifier: String) async throws -> Data
    func setDirectory(_ url: URL) async
    func filterDroppedFiles(urls: [URL], existingIdentifiers: [String]) -> [String]
}
