import Foundation

final class SetDirectoryUseCase: SetDirectoryUseCaseProtocol {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute(url: URL) async {
        await imageRepository.setDirectory(url)
    }
}
