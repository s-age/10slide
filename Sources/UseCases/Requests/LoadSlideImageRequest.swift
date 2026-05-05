struct LoadSlideImageRequest: UseCaseRequest {
    let localIdentifier: String

    func validate() throws {}
}
