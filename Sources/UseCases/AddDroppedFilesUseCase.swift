import Foundation

final class AddDroppedFilesUseCase: AddDroppedFilesUseCaseProtocol, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AddDroppedFilesRequest) throws -> [String] {
        try request.validate()
        return domainService.filterDroppedFiles(
            urls: request.urls,
            existingIdentifiers: request.existingIdentifiers
        )
    }
}
