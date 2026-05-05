final class PreviousSlideUseCase: SyncUseCase, Sendable {
    private let domainService: any PlaybackDomainServiceProtocol

    init(domainService: any PlaybackDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: PreviousSlideRequest) throws -> Int? {
        domainService.previousIndex(
            totalSlides: request.totalSlides,
            currentIndex: request.currentIndex,
            loop: request.loop
        )
    }
}
