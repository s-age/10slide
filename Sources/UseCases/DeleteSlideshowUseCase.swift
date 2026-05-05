import Foundation

final class DeleteSlideshowUseCase: DeleteSlideshowUseCaseProtocol, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: DeleteSlideshowRequest) async throws {
        try request.validate()
        try await domainService.delete(id: request.id)
    }
}
