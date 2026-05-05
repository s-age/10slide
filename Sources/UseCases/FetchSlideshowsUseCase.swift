final class FetchSlideshowsUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchSlideshowsRequest) async throws -> [SlideshowResponse] {
        let slideshows = try await domainService.fetchAll()
        return slideshows.map { SlideshowResponse(from: $0) }
    }
}
