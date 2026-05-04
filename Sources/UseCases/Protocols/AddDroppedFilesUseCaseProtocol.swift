import Foundation

protocol AddDroppedFilesUseCaseProtocol: Sendable {
    func execute(urls: [URL], existingIdentifiers: [String]) -> [String]
}
