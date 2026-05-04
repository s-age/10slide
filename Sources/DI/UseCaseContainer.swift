final class UseCaseContainer {
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

    init(repositories: RepositoryContainer) {
        createSlideshow = CreateSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository
        )
        fetchSlideshow = FetchSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository
        )
        fetchSlideshows = FetchSlideshowsUseCase(
            slideshowRepository: repositories.slideshowRepository
        )
        fetchLibrary = FetchLibraryUseCase(
            imageRepository: repositories.imageRepository
        )
        loadSlideImage = LoadSlideImageUseCase(
            imageRepository: repositories.imageRepository
        )
        loadThumbnail = LoadThumbnailUseCase(
            imageRepository: repositories.imageRepository
        )
        loadConfig = LoadConfigUseCase(
            configRepository: repositories.configRepository
        )
        saveConfig = SaveConfigUseCase(
            configRepository: repositories.configRepository
        )
        updateSlideshowConfig = UpdateSlideshowConfigUseCase()
        advanceSlide = AdvanceSlideUseCase()
        setDirectory = SetDirectoryUseCase(imageRepository: repositories.imageRepository)
        addDroppedFiles = AddDroppedFilesUseCase(imageRepository: repositories.imageRepository)
        deleteSlideshow = DeleteSlideshowUseCase(slideshowRepository: repositories.slideshowRepository)
    }
}
