final class UseCaseContainer: Sendable {
    let createSlideshow: any CreateSlideshowUseCaseProtocol
    let fetchSlideshow: any FetchSlideshowUseCaseProtocol
    let fetchSlideshows: any FetchSlideshowsUseCaseProtocol
    let fetchLibrary: any FetchLibraryUseCaseProtocol
    let loadSlideImage: any LoadSlideImageUseCaseProtocol
    let loadThumbnail: any LoadThumbnailUseCaseProtocol
    let loadConfig: any LoadConfigUseCaseProtocol
    let saveConfig: any SaveConfigUseCaseProtocol
    let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
    let advanceSlide: any AdvanceSlideUseCaseProtocol
    let setDirectory: any SetDirectoryUseCaseProtocol
    let addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    let deleteSlideshow: any DeleteSlideshowUseCaseProtocol
    let updateSlideshow: any UpdateSlideshowUseCaseProtocol

    init(domain: DomainContainer) {
        createSlideshow = CreateSlideshowUseCase(
            domainService: domain.slideshowService
        )
        fetchSlideshow = FetchSlideshowUseCase(
            domainService: domain.slideshowService
        )
        fetchSlideshows = FetchSlideshowsUseCase(
            domainService: domain.slideshowService
        )
        fetchLibrary = FetchLibraryUseCase(
            domainService: domain.imageService
        )
        loadSlideImage = LoadSlideImageUseCase(
            domainService: domain.imageService
        )
        loadThumbnail = LoadThumbnailUseCase(
            domainService: domain.imageService
        )
        loadConfig = LoadConfigUseCase(
            domainService: domain.configService
        )
        saveConfig = SaveConfigUseCase(
            domainService: domain.configService
        )
        updateSlideshowConfig = UpdateSlideshowConfigUseCase(
            domainService: domain.slideshowService,
            playbackService: domain.playbackService
        )
        advanceSlide = AdvanceSlideUseCase(
            domainService: domain.playbackService
        )
        setDirectory = SetDirectoryUseCase(
            domainService: domain.imageService
        )
        addDroppedFiles = AddDroppedFilesUseCase(
            domainService: domain.imageService
        )
        deleteSlideshow = DeleteSlideshowUseCase(
            domainService: domain.slideshowService
        )
        updateSlideshow = UpdateSlideshowUseCase(
            domainService: domain.slideshowService
        )
    }
}
