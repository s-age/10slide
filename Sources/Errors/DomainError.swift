import Foundation

enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .slideshowNotFound(let id):
            return String(localized: "Slideshow not found: \(id.uuidString)")
        }
    }
}
