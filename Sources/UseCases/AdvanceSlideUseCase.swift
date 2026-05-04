final class AdvanceSlideUseCase: AdvanceSlideUseCaseProtocol {
    func execute(currentIndex: Int, slideCount: Int, loop: Bool) -> Int? {
        guard slideCount > 0 else { return nil }
        if currentIndex < slideCount - 1 {
            return currentIndex + 1
        }
        return loop ? 0 : nil
    }

    func executePrevious(currentIndex: Int, slideCount: Int, loop: Bool) -> Int? {
        guard slideCount > 0 else { return nil }
        if currentIndex > 0 {
            return currentIndex - 1
        }
        return loop ? slideCount - 1 : nil
    }
}
