import Foundation

enum ValidationError: LocalizedError, Sendable {
    case emptyName
    case noIdentifiers
    case invalidIndex
    case noSlides

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return String(localized: "Name must not be empty")
        case .noIdentifiers:
            return String(localized: "At least one image must be selected")
        case .invalidIndex:
            return String(localized: "Slide index is out of range")
        case .noSlides:
            return String(localized: "Slideshow has no slides")
        }
    }
}
