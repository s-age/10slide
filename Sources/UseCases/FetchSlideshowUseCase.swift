import Foundation

final class FetchSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchSlideshowRequest) async throws -> SlideshowResponse? {
        guard let slideshow = try await domainService.fetch(id: request.id) else { return nil }
        return SlideshowResponse(from: slideshow)
    }
}
