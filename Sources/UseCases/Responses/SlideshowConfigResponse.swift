struct SlideshowConfigResponse: Equatable, Sendable {
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    static let `default` = SlideshowConfigResponse(
        duration: .five,
        transition: .fade,
        loop: true
    )
}
