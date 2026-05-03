import Foundation

protocol LoadSlideImageUseCaseProtocol: Sendable {
    func execute(localIdentifier: String) async throws -> Data
}
