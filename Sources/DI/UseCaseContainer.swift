final class UseCaseContainer: Sendable {
    let createSlideshow: CreateSlideshowUseCaseProtocol
    let fetchSlideshow: FetchSlideshowUseCaseProtocol
    let fetchSlideshows: FetchSlideshowsUseCaseProtocol
    let fetchLibrary: FetchLibraryUseCaseProtocol
    let loadSlideImage: LoadSlideImageUseCaseProtocol
    let loadThumbnail: LoadThumbnailUseCaseProtocol
    let loadConfig: LoadConfigUseCaseProtocol
    let saveConfig: SaveConfigUseCaseProtocol
    let updateSlideshowConfig: UpdateSlideshowConfigUseCaseProtocol
    let advanceSlide: AdvanceSlideUseCaseProtocol
    let previousSlide: PreviousSlideUseCaseProtocol
    let setDirectory: SetDirectoryUseCaseProtocol
    let addDroppedFiles: AddDroppedFilesUseCaseProtocol
    let deleteSlideshow: DeleteSlideshowUseCaseProtocol
    let updateSlideshow: UpdateSlideshowUseCaseProtocol

    init(domain: DomainContainer) {
        createSlideshow = ValidationAsyncUseCaseDecorator(
            decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
        )
        fetchSlideshow = ValidationAsyncUseCaseDecorator(
            decoratee: FetchSlideshowUseCase(domainService: domain.slideshowService)
        )
        fetchSlideshows = ValidationAsyncUseCaseDecorator(
            decoratee: FetchSlideshowsUseCase(domainService: domain.slideshowService)
        )
        fetchLibrary = ValidationAsyncUseCaseDecorator(
            decoratee: FetchLibraryUseCase(domainService: domain.imageService)
        )
        loadSlideImage = ValidationAsyncUseCaseDecorator(
            decoratee: LoadSlideImageUseCase(domainService: domain.imageService)
        )
        loadThumbnail = ValidationAsyncUseCaseDecorator(
            decoratee: LoadThumbnailUseCase(domainService: domain.imageService)
        )
        loadConfig = ValidationAsyncUseCaseDecorator(
            decoratee: LoadConfigUseCase(domainService: domain.configService)
        )
        saveConfig = ValidationAsyncUseCaseDecorator(
            decoratee: SaveConfigUseCase(domainService: domain.configService)
        )
        updateSlideshowConfig = ValidationAsyncUseCaseDecorator(
            decoratee: UpdateSlideshowConfigUseCase(domainService: domain.slideshowService)
        )
        advanceSlide = ValidationSyncUseCaseDecorator(
            decoratee: AdvanceSlideUseCase(domainService: domain.playbackService)
        )
        previousSlide = ValidationSyncUseCaseDecorator(
            decoratee: PreviousSlideUseCase(domainService: domain.playbackService)
        )
        setDirectory = ValidationAsyncUseCaseDecorator(
            decoratee: SetDirectoryUseCase(domainService: domain.imageService)
        )
        addDroppedFiles = ValidationSyncUseCaseDecorator(
            decoratee: AddDroppedFilesUseCase(domainService: domain.imageService)
        )
        deleteSlideshow = ValidationAsyncUseCaseDecorator(
            decoratee: DeleteSlideshowUseCase(domainService: domain.slideshowService)
        )
        updateSlideshow = ValidationAsyncUseCaseDecorator(
            decoratee: UpdateSlideshowUseCase(domainService: domain.slideshowService)
        )
    }
}
