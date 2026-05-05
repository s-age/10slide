import Foundation

struct AddDroppedFilesRequest: UseCaseRequest {
    let urls: [URL]
    let existingIdentifiers: [String]

    func validate() throws {}
}
