import Foundation

protocol CreateSlideshowUseCaseProtocol: Sendable {
    func execute(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow
}
