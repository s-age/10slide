protocol SaveConfigUseCaseProtocol: Sendable {
    func execute(_ request: SaveConfigRequest) async throws
}
