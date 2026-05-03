final class RepositoryContainer {
    let slideRepository: any SlideRepositoryProtocol
    let slideshowRepository: any SlideshowRepositoryProtocol
    let configRepository: any ConfigRepositoryProtocol
    let imageRepository: any ImageRepositoryProtocol

    init(infrastructure: InfrastructureContainer) {
        slideRepository = SlideRepository(
            slideDataSource: infrastructure.slideDataSource,
            imageDataSource: infrastructure.imageDataSource
        )
        slideshowRepository = SlideshowRepository(
            slideshowDataSource: infrastructure.slideshowDataSource,
            slideDataSource: infrastructure.slideDataSource
        )
        configRepository = ConfigRepository(configDataSource: infrastructure.configDataSource)
        imageRepository = ImageRepository(imageDataSource: infrastructure.imageDataSource)
    }
}
