protocol ImageDataSourceProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImage(localIdentifier: String) async throws -> ImageDTO
}
