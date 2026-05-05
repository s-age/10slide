import Foundation

struct DeleteSlideshowRequest: UseCaseRequest {
    let id: UUID

    func validate() throws {}
}
