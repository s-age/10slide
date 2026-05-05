protocol FetchSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: FetchSlideshowRequest) async throws -> SlideshowResponse?
}
