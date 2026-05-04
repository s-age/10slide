import Foundation

protocol SetDirectoryUseCaseProtocol: Sendable {
    func execute(url: URL) async
}
