import Foundation

final class LoadThumbnailUseCase: AsyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadThumbnailRequest) async throws -> Data {
        return try await domainService.fetchThumbnailData(localIdentifier: request.localIdentifier)
    }
}
