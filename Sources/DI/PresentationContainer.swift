final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol
    private let loadSlideImage: LoadSlideImageUseCaseProtocol
    private let loadThumbnail: LoadThumbnailUseCaseProtocol
    private let updateSlideshowConfig: UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlide: AdvanceSlideUseCaseProtocol
    private let previousSlide: PreviousSlideUseCaseProtocol
    private let addDroppedFiles: AddDroppedFilesUseCaseProtocol
    private let fetchSlideshows: FetchSlideshowsUseCaseProtocol
    private let deleteSlideshow: DeleteSlideshowUseCaseProtocol
    private let updateSlideshow: UpdateSlideshowUseCaseProtocol

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        loadThumbnail = useCases.loadThumbnail
        updateSlideshowConfig = useCases.updateSlideshowConfig
        advanceSlide = useCases.advanceSlide
        previousSlide = useCases.previousSlide
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
    func makeSlideshowPlayerViewModel(slideshow: SlideshowResponse) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(
            slideshow: slideshow,
            loadSlideImage: loadSlideImage,
            updateSlideshowConfig: updateSlideshowConfig,
            advanceSlide: advanceSlide,
            previousSlide: previousSlide
        )
    }

    @MainActor
    func makeSlideshowLibraryViewModel() -> SlideshowLibraryViewModel {
        SlideshowLibraryViewModel(fetchSlideshows: fetchSlideshows, deleteSlideshow: deleteSlideshow)
    }
}
