protocol FetchLibraryUseCaseProtocol: Sendable {
    func execute() async throws -> [String]
}
