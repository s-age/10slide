import Foundation

final class LoadSlideImageUseCase: LoadSlideImageUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadSlideImageRequest) async throws -> Data {
        try request.validate()
        return try await domainService.fetchImageData(localIdentifier: request.localIdentifier)
    }
}
