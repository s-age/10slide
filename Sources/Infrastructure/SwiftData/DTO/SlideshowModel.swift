import SwiftData
import Foundation

@Model
final class SlideshowModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var defaultDuration: TimeInterval
    var transitionRawValue: String
    var loop: Bool
    @Relationship(deleteRule: .cascade, inverse: \SlideModel.slideshow) var slides: [SlideModel]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        defaultDuration: TimeInterval = 5.0,
        transitionRawValue: String = "fade",
        loop: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.defaultDuration = defaultDuration
        self.transitionRawValue = transitionRawValue
        self.loop = loop
        self.slides = []
    }
}
