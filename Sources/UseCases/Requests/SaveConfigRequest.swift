struct SaveConfigRequest: UseCaseRequest {
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {}
}
