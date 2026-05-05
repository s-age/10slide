import Foundation

struct UpdateSlideshowRequest: UseCaseRequest {
    let id: UUID
    let name: String
    let localIdentifiers: [String]

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
