import Foundation

struct ConfigDTO: Sendable, Codable {
    var duration: String
    var transition: String
    var loop: Bool
}
