import Foundation

enum DomainError: Error, Sendable {
    case slideshowNotFound(UUID)
}
