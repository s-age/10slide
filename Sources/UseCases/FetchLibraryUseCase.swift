import Foundation

final class FetchLibraryUseCase: FetchLibraryUseCaseProtocol, Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute() async throws -> [String] {
        try await imageRepository.fetchAllIdentifiers()
    }
}
