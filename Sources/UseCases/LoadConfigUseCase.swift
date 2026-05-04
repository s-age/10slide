import Foundation

final class LoadConfigUseCase: LoadConfigUseCaseProtocol, Sendable {
    private let configRepository: any ConfigRepositoryProtocol

    init(configRepository: any ConfigRepositoryProtocol) {
        self.configRepository = configRepository
    }

    func execute() async throws -> SlideshowConfig {
        try await configRepository.load()
    }
}
