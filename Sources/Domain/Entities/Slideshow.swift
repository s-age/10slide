import Foundation

struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig
    var createdAt: Date
}
