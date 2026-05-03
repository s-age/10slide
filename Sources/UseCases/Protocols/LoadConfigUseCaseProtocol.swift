protocol LoadConfigUseCaseProtocol: Sendable {
    func execute() async throws -> SlideshowConfig
}
