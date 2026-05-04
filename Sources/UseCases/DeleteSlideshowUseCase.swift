import Foundation

final class DeleteSlideshowUseCase: DeleteSlideshowUseCaseProtocol {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(id: UUID) async throws {
        try await slideshowRepository.delete(id: id)
    }
}
