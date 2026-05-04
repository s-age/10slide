import Foundation

final class LoadThumbnailUseCase: LoadThumbnailUseCaseProtocol, Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute(localIdentifier: String) async throws -> Data {
        try await imageRepository.fetchThumbnailData(localIdentifier: localIdentifier)
    }
}
