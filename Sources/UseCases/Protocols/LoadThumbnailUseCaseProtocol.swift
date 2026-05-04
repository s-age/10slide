import Foundation

protocol LoadThumbnailUseCaseProtocol: Sendable {
    func execute(localIdentifier: String) async throws -> Data
}
