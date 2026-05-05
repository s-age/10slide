import Foundation

final class UpdateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: UpdateSlideshowRequest) async throws -> SlideshowResponse {
        let slideshow = try await domainService.update(
            id: request.id,
            name: request.name,
            localIdentifiers: request.localIdentifiers
        )
        return SlideshowResponse(from: slideshow)
    }
}
