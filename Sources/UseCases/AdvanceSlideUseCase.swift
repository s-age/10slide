final class AdvanceSlideUseCase: AdvanceSlideUseCaseProtocol, Sendable {
    private let domainService: any PlaybackDomainServiceProtocol

    init(domainService: any PlaybackDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        try request.validate()
        return domainService.nextIndex(
            totalSlides: request.totalSlides,
            currentIndex: request.currentIndex,
            loop: request.loop
        )
    }

    func executePrevious(_ request: PreviousSlideRequest) throws -> Int? {
        try request.validate()
        return domainService.previousIndex(
            totalSlides: request.totalSlides,
            currentIndex: request.currentIndex,
            loop: request.loop
        )
    }
}
