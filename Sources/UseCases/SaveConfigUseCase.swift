import Foundation

final class SaveConfigUseCase: SaveConfigUseCaseProtocol, Sendable {
    private let domainService: any ConfigDomainServiceProtocol

    init(domainService: any ConfigDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: SaveConfigRequest) async throws {
        try request.validate()
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        try await domainService.save(config)
    }
}
