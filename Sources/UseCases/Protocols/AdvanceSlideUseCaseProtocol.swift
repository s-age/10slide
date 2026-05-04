protocol AdvanceSlideUseCaseProtocol: Sendable {
    func execute(currentIndex: Int, slideCount: Int, loop: Bool) -> Int?
    func executePrevious(currentIndex: Int, slideCount: Int, loop: Bool) -> Int?
}
