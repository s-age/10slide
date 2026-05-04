import Foundation

protocol UpdateSlideshowUseCaseProtocol: Sendable {
    func execute(slideshow: Slideshow, name: String, localIdentifiers: [String]) async throws -> Slideshow
}
