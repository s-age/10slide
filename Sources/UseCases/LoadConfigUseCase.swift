import Foundation

final class LoadConfigUseCase: AsyncUseCase, Sendable {
    private let domainService: any ConfigDomainServiceProtocol

    init(domainService: any ConfigDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: LoadConfigRequest) async throws -> SlideshowConfigResponse {
        let config = try await domainService.load()
        return SlideshowConfigResponse(from: config)
    }
}
