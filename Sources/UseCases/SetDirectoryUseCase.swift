import Foundation

final class SetDirectoryUseCase: AsyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: SetDirectoryRequest) async throws {
        await domainService.setDirectory(request.url)
    }
}
