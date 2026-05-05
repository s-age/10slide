import Foundation

struct SetDirectoryRequest: UseCaseRequest {
    let url: URL

    func validate() throws {}
}
