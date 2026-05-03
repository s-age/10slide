final class RepositoryContainer {
    let slideRepository: any SlideRepositoryProtocol

    init(infrastructure: InfrastructureContainer) {
        slideRepository = SlideRepository(
            slideDataSource: infrastructure.slideDataSource,
            imageDataSource: infrastructure.imageDataSource
        )
    }
}
