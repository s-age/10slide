import Foundation

final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        let slideshow = try await domainService.create(
            name: request.name,
            localIdentifiers: request.localIdentifiers,
            config: config
        )
        return SlideshowResponse(from: slideshow)
    }
}
