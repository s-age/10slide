import Foundation

struct ConfigDTO: Sendable, Codable {
    var defaultDuration: TimeInterval
    var transition: String
    var loop: Bool
}
