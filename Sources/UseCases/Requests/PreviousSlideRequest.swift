struct PreviousSlideRequest: UseCaseRequest {
    let totalSlides: Int
    let currentIndex: Int
    let loop: Bool

    func validate() throws {
        guard totalSlides > 0 else { throw ValidationError.noSlides }
        guard currentIndex >= 0, currentIndex < totalSlides else {
            throw ValidationError.invalidIndex
        }
    }
}
