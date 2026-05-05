import Foundation

struct SlideResponse: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
    let duration: TimeInterval
    let title: String?
}
