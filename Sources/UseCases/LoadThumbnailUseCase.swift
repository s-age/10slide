import Foundation

final class LoadThumbnailUseCase: LoadThumbnailUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadThumbnailRequest) async throws -> Data {
        try request.validate()
        return try await domainService.fetchThumbnailData(localIdentifier: request.localIdentifier)
    }
}
