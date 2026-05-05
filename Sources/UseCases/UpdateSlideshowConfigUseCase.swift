import Foundation

final class UpdateSlideshowConfigUseCase: UpdateSlideshowConfigUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol
    private let playbackService: any PlaybackDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol, playbackService: any PlaybackDomainServiceProtocol) {
        self.domainService = domainService
        self.playbackService = playbackService
    }

    func execute(_ request: UpdateSlideshowConfigRequest) async throws -> SlideshowResponse {
        try request.validate()
        guard let slideshow = try await domainService.fetch(id: request.slideshowID) else {
            throw DomainError.slideshowNotFound(request.slideshowID)
        }
        let newConfig = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        let updated = playbackService.applyConfig(newConfig, to: slideshow)
        return SlideshowResponse(from: updated)
    }
}
