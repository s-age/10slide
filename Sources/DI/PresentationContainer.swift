final class PresentationContainer {
    private let fetchLibrary: any FetchLibraryUseCaseProtocol
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol
    private let loadThumbnail: any LoadThumbnailUseCaseProtocol
    private let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlide: any AdvanceSlideUseCaseProtocol
    private let setDirectory: any SetDirectoryUseCaseProtocol
    private let addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    private let fetchSlideshows: any FetchSlideshowsUseCaseProtocol
    private let deleteSlideshow: any DeleteSlideshowUseCaseProtocol

    init(useCases: UseCaseContainer) {
        fetchLibrary = useCases.fetchLibrary
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        loadThumbnail = useCases.loadThumbnail
        updateSlideshowConfig = useCases.updateSlideshowConfig
        advanceSlide = useCases.advanceSlide
        setDirectory = useCases.setDirectory
        addDroppedFiles = useCases.addDroppedFiles
        fetchSlideshows = useCases.fetchSlideshows
        deleteSlideshow = useCases.deleteSlideshow
    }

    @MainActor
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(
            fetchLibrary: fetchLibrary,
            setDirectory: setDirectory,
            addDroppedFiles: addDroppedFiles
        )
    }

    @MainActor
    func makeThumbnailViewModel() -> ThumbnailViewModel {
        ThumbnailViewModel(loadThumbnail: loadThumbnail)
    }

    @MainActor
    func makeCreateSlideshowViewModel() -> CreateSlideshowViewModel {
        CreateSlideshowViewModel(createSlideshow: createSlideshow)
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
