import Foundation

final class FetchLibraryUseCase: AsyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchLibraryRequest) async throws -> [String] {
        return try await domainService.fetchAllIdentifiers()
    }
}
