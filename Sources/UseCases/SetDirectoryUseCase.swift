import Foundation

final class SetDirectoryUseCase: SetDirectoryUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: SetDirectoryRequest) async throws {
        try request.validate()
        await domainService.setDirectory(request.url)
    }
}
