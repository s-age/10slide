import Foundation

protocol LoadSlideImageUseCaseProtocol: Sendable {
    func execute(_ request: LoadSlideImageRequest) async throws -> Data
}
