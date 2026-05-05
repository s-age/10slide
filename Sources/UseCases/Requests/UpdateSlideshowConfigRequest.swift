import Foundation

struct UpdateSlideshowConfigRequest: UseCaseRequest {
    let slideshowID: UUID
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {}
}
