import Foundation

final class FetchLibraryUseCase: FetchLibraryUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchLibraryRequest) async throws -> [String] {
        try request.validate()
        return try await domainService.fetchAllIdentifiers()
    }
}
