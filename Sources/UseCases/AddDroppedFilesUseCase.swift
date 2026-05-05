import Foundation

final class AddDroppedFilesUseCase: SyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AddDroppedFilesRequest) throws -> [String] {
        domainService.filterDroppedFiles(
            urls: request.urls,
            existingIdentifiers: request.existingIdentifiers
        )
    }
}
