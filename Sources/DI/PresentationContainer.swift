final class PresentationContainer: Sendable {
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol
    private let loadThumbnail: any LoadThumbnailUseCaseProtocol
    private let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlide: any AdvanceSlideUseCaseProtocol
    private let addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    private let fetchSlideshows: any FetchSlideshowsUseCaseProtocol
    private let deleteSlideshow: any DeleteSlideshowUseCaseProtocol
    private let updateSlideshow: any UpdateSlideshowUseCaseProtocol

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        loadThumbnail = useCases.loadThumbnail
        updateSlideshowConfig = useCases.updateSlideshowConfig
        advanceSlide = useCases.advanceSlide
        addDroppedFiles = useCases.addDroppedFiles
        fetchSlideshows = useCases.fetchSlideshows
        deleteSlideshow = useCases.deleteSlideshow
        updateSlideshow = useCases.updateSlideshow
    }

    @MainActor
    func makeThumbnailViewModel() -> ThumbnailViewModel {
        ThumbnailViewModel(loadThumbnail: loadThumbnail)
    }

    @MainActor
    func makeCreateSlideshowViewModel() -> CreateSlideshowViewModel {
        CreateSlideshowViewModel(
            createSlideshow: createSlideshow,
            updateSlideshow: updateSlideshow,
            addDroppedFiles: addDroppedFiles
        )
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: Slideshow) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(
            slideshow: slideshow,
            loadSlideImage: loadSlideImage,
            updateSlideshowConfig: updateSlideshowConfig,
            advanceSlide: advanceSlide
        )
    }

    @MainActor
    func makeSlideshowLibraryViewModel() -> SlideshowLibraryViewModel {
        SlideshowLibraryViewModel(fetchSlideshows: fetchSlideshows, deleteSlideshow: deleteSlideshow)
    }
}
