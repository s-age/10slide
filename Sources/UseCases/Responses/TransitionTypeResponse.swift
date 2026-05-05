enum TransitionTypeResponse: String, Equatable, Sendable, CaseIterable {
    case none
    case fade
    case slide
    case dissolve

    static let `default` = TransitionTypeResponse.fade
}
