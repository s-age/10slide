import Foundation

final class ImageRepository: ImageRepositoryProtocol {
    private let imageDataSource: any ImageDataSourceProtocol

    init(imageDataSource: any ImageDataSourceProtocol) {
        self.imageDataSource = imageDataSource
    }

    func fetchAllIdentifiers() async throws -> [String] {
        try await imageDataSource.fetchAllIdentifiers()
    }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        let dto = try await imageDataSource.fetchImage(localIdentifier: localIdentifier)
        return dto.data
    }

    func fetchThumbnailData(localIdentifier: String) async throws -> Data {
        try await imageDataSource.fetchThumbnail(localIdentifier: localIdentifier)
    }
}
