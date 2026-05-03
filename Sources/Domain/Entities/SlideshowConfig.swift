import Foundation

struct SlideshowConfig: Equatable, Sendable, Codable {
    var defaultDuration: TimeInterval
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(
        defaultDuration: 5.0,
        transition: .fade,
        loop: true
    )
}
