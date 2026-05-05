protocol FetchLibraryUseCaseProtocol: Sendable {
    func execute(_ request: FetchLibraryRequest) async throws -> [String]
}
