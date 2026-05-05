import Foundation

enum ValidationError: Error, Sendable {
    case emptyName
    case noIdentifiers
    case invalidIndex
    case noSlides
}
