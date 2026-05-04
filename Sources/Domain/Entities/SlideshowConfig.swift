import Foundation

struct SlideshowConfig: Equatable, Sendable, Codable {
    var duration: SlideDuration
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(
        duration: .five,
        transition: .fade,
        loop: true
    )
}
