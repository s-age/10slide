import Foundation

protocol FetchSlideshowUseCaseProtocol: Sendable {
    func execute(id: UUID) async throws -> Slideshow?
}
