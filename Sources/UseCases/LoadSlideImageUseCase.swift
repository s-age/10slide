import Foundation

final class LoadSlideImageUseCase: LoadSlideImageUseCaseProtocol, Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute(localIdentifier: String) async throws -> Data {
        try await imageRepository.fetchImageData(localIdentifier: localIdentifier)
    }
}
