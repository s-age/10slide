import Foundation

final class SaveConfigUseCase: SaveConfigUseCaseProtocol, Sendable {
    private let configRepository: any ConfigRepositoryProtocol

    init(configRepository: any ConfigRepositoryProtocol) {
        self.configRepository = configRepository
    }

    func execute(_ config: SlideshowConfig) async throws {
        try await configRepository.save(config)
    }
}
