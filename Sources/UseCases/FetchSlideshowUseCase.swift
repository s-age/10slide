import Foundation

final class FetchSlideshowUseCase: FetchSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchSlideshowRequest) async throws -> SlideshowResponse? {
        try request.validate()
        guard let slideshow = try await domainService.fetch(id: request.id) else { return nil }
        return SlideshowResponse(from: slideshow)
    }
}
