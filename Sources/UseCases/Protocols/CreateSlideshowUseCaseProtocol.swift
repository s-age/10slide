protocol CreateSlideshowUseCaseProtocol: Sendable {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse
}
