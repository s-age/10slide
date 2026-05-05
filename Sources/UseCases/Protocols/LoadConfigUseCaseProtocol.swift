protocol LoadConfigUseCaseProtocol: Sendable {
    func execute(_ request: LoadConfigRequest) async throws -> SlideshowConfigResponse
}
