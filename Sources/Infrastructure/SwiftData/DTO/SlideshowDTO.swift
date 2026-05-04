import Foundation

struct SlideshowDTO: Sendable {
    let id: UUID
    let name: String
    let createdAt: Date
    let durationRawValue: String
    let transitionRawValue: String
    let loop: Bool
    let slides: [SlideDTO]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        durationRawValue: String = "5",
        transitionRawValue: String = "fade",
        loop: Bool = true,
        slides: [SlideDTO] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.durationRawValue = durationRawValue
        self.transitionRawValue = transitionRawValue
        self.loop = loop
        self.slides = slides
    }
}
