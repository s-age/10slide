import Foundation

protocol LoadThumbnailUseCaseProtocol: Sendable {
    func execute(_ request: LoadThumbnailRequest) async throws -> Data
}
