import Foundation

final class UpdateSlideshowUseCase: UpdateSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: UpdateSlideshowRequest) async throws -> SlideshowResponse {
        try request.validate()
        let slideshow = try await domainService.update(
            id: request.id,
            name: request.name,
            localIdentifiers: request.localIdentifiers
        )
        return SlideshowResponse(from: slideshow)
    }
}
