protocol AdvanceSlideUseCaseProtocol: Sendable {
    func execute(_ request: AdvanceSlideRequest) throws -> Int?
    func executePrevious(_ request: PreviousSlideRequest) throws -> Int?
}
