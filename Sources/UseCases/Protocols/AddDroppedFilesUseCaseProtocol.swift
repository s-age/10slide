protocol AddDroppedFilesUseCaseProtocol: Sendable {
    func execute(_ request: AddDroppedFilesRequest) throws -> [String]
}
