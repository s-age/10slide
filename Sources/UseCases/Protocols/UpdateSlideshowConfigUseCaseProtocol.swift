protocol UpdateSlideshowConfigUseCaseProtocol: Sendable {
    func execute(_ request: UpdateSlideshowConfigRequest) async throws -> SlideshowResponse
}
