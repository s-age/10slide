import Foundation

struct FetchSlideshowRequest: UseCaseRequest {
    let id: UUID

    func validate() throws {}
}
