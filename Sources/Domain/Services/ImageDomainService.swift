import Foundation

final class ImageDomainService: ImageDomainServiceProtocol, Sendable {
    private let repository: any ImageRepositoryProtocol

    init(repository: any ImageRepositoryProtocol) {
        self.repository = repository
    }

    func fetchAllIdentifiers() async throws -> [String] {
        try await repository.fetchAllIdentifiers()
    }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        try await repository.fetchImageData(localIdentifier: localIdentifier)
    }

    func fetchThumbnailData(localIdentifier: String) async throws -> Data {
        try await repository.fetchThumbnailData(localIdentifier: localIdentifier)
    }

    func setDirectory(_ url: URL) async {
        await repository.setDirectory(url)
    }

    func filterDroppedFiles(urls: [URL], existingIdentifiers: [String]) -> [String] {
        let supported = repository.supportedExtensions
        let existing = Set(existingIdentifiers)
        return urls
            .filter { supported.contains($0.pathExtension.lowercased()) }
            .map { $0.path }
            .filter { !existing.contains($0) }
    }
}
