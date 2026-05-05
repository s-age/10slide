import Foundation

final class LoadSlideImageUseCase: AsyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadSlideImageRequest) async throws -> Data {
        return try await domainService.fetchImageData(localIdentifier: request.localIdentifier)
    }
}
