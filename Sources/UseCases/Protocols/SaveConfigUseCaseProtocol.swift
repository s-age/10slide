protocol SaveConfigUseCaseProtocol: Sendable {
    func execute(_ config: SlideshowConfig) async throws
}
