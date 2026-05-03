import Foundation
import Photos

final class ImageDataSource: ImageDataSourceProtocol {
    func fetchAllIdentifiers() async throws -> [String] {
        []
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        fatalError("Not implemented")
    }
}
