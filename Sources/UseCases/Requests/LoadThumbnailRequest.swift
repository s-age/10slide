struct LoadThumbnailRequest: UseCaseRequest {
    let localIdentifier: String

    func validate() throws {}
}
