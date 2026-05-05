import Foundation

final class SaveConfigUseCase: AsyncUseCase, Sendable {
    private let domainService: any ConfigDomainServiceProtocol

    init(domainService: any ConfigDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: SaveConfigRequest) async throws {
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        try await domainService.save(config)
    }
}
