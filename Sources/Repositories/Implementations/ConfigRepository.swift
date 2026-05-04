import Foundation

final class ConfigRepository: ConfigRepositoryProtocol {
    private let configDataSource: any ConfigDataSourceProtocol

    init(configDataSource: any ConfigDataSourceProtocol) {
        self.configDataSource = configDataSource
    }

    func load() async throws -> SlideshowConfig {
        guard let dto = try await configDataSource.load() else {
            return .default
        }
        return SlideshowConfig(
            duration: SlideDuration(rawValue: dto.duration) ?? .five,
            transition: TransitionType(rawValue: dto.transition) ?? .default,
            loop: dto.loop
        )
    }

    func save(_ config: SlideshowConfig) async throws {
        let dto = ConfigDTO(
            duration: config.duration.rawValue,
            transition: config.transition.rawValue,
            loop: config.loop
        )
        try await configDataSource.save(dto)
    }
}
