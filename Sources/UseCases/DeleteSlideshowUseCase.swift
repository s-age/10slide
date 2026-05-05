import Foundation

final class DeleteSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: DeleteSlideshowRequest) async throws {
        try await domainService.delete(id: request.id)
    }
}
