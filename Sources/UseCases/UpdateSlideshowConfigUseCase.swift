import Foundation

final class UpdateSlideshowConfigUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: UpdateSlideshowConfigRequest) async throws -> SlideshowResponse {
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        let updated = try await domainService.updateConfig(id: request.slideshowID, config: config)
        return SlideshowResponse(from: updated)
    }
}
