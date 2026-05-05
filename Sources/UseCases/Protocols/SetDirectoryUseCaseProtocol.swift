protocol SetDirectoryUseCaseProtocol: Sendable {
    func execute(_ request: SetDirectoryRequest) async throws
}
