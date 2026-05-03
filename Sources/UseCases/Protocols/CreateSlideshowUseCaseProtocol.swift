import Foundation

protocol CreateSlideshowUseCaseProtocol: Sendable {
    func execute(name: String, localIdentifiers: [String]) async throws -> Slideshow
}
