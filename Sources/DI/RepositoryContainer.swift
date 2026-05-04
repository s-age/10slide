final class RepositoryContainer {
    let slideRepository: any SlideRepositoryProtocol
    let slideshowRepository: any SlideshowRepositoryProtocol
    let configRepository: any ConfigRepositoryProtocol
    let imageRepository: any ImageRepositoryProtocol

    init(infrastructure: InfrastructureContainer) {
        slideRepository = SlideRepository(store: infrastructure.swiftDataStore)
        slideshowRepository = SlideshowRepository(store: infrastructure.swiftDataStore)
        configRepository = ConfigRepository(configDataSource: infrastructure.configDataSource)
        imageRepository = ImageRepository(imageDataSource: infrastructure.imageDataSource)
    }
}
