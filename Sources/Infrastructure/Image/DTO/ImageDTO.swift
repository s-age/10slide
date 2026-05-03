import Foundation

struct ImageDTO: Sendable {
    let localIdentifier: String
    let data: Data
    let creationDate: Date?
}
