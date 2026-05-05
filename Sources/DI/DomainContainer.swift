final class DomainContainer: Sendable {
    let slideshowService: any SlideshowDomainServiceProtocol
    let imageService: any ImageDomainServiceProtocol
    let configService: any ConfigDomainServiceProtocol
    let playbackService: any PlaybackDomainServiceProtocol

    init(repositories: RepositoryContainer) {
        slideshowService = SlideshowDomainService(
            repository: repositories.slideshowRepository
        )
        imageService = ImageDomainService(
            repository: repositories.imageRepository
        )
        configService = ConfigDomainService(
            repository: repositories.configRepository
        )
        playbackService = PlaybackDomainService()
    }
}
