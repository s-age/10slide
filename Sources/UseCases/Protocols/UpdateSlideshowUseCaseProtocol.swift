protocol UpdateSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: UpdateSlideshowRequest) async throws -> SlideshowResponse
}
