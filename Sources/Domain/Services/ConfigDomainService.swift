import Foundation

final class ConfigDomainService: ConfigDomainServiceProtocol, Sendable {
    private let repository: any ConfigRepositoryProtocol

    init(repository: any ConfigRepositoryProtocol) {
        self.repository = repository
    }

    func load() async throws -> SlideshowConfig {
        try await repository.load()
    }

    func save(_ config: SlideshowConfig) async throws {
        try await repository.save(config)
    }
}
