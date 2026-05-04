import Foundation

protocol DeleteSlideshowUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws
}
