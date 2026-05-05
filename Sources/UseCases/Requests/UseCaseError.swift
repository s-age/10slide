import Foundation

enum UseCaseError: Error, Sendable {
    case slideshowNotFound(UUID)
}
