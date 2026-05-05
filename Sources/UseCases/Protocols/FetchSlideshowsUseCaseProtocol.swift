protocol FetchSlideshowsUseCaseProtocol: Sendable {
    func execute(_ request: FetchSlideshowsRequest) async throws -> [SlideshowResponse]
}
