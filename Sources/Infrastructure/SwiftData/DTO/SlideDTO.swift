import Foundation

struct SlideDTO: Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
    let duration: TimeInterval
    let title: String?

    init(
        id: UUID = UUID(),
        localIdentifier: String,
        order: Int,
        duration: TimeInterval = 3.0,
        title: String? = nil
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.order = order
        self.duration = duration
        self.title = title
    }
}
