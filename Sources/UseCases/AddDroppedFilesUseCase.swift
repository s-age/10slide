import Foundation

final class AddDroppedFilesUseCase: AddDroppedFilesUseCaseProtocol, Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute(urls: [URL], existingIdentifiers: [String]) -> [String] {
        let supported = imageRepository.supportedExtensions
        let existing = Set(existingIdentifiers)
        return urls
            .filter { supported.contains($0.pathExtension.lowercased()) }
            .map { $0.path }
            .filter { !existing.contains($0) }
    }
}
