final class FetchSlideshowsUseCase: FetchSlideshowsUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchSlideshowsRequest) async throws -> [SlideshowResponse] {
        try request.validate()
        let slideshows = try await domainService.fetchAll()
        return slideshows.map { SlideshowResponse(from: $0) }
    }
}
