final class UseCaseContainer {
    let createSlideshow: any CreateSlideshowUseCaseProtocol
    let fetchSlideshow: any FetchSlideshowUseCaseProtocol
    let fetchLibrary: any FetchLibraryUseCaseProtocol
    let loadSlideImage: any LoadSlideImageUseCaseProtocol
    let loadThumbnail: any LoadThumbnailUseCaseProtocol
    let loadConfig: any LoadConfigUseCaseProtocol
    let saveConfig: any SaveConfigUseCaseProtocol
    let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol

    init(repositories: RepositoryContainer) {
        createSlideshow = CreateSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository
        )
        fetchSlideshow = FetchSlideshowUseCase(
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
    }
}
