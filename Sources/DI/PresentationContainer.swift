final class PresentationContainer {
    private let fetchLibrary: any FetchLibraryUseCaseProtocol
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol
    private let loadThumbnail: any LoadThumbnailUseCaseProtocol
    private let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
    private let setDirectory: any SetDirectoryUseCaseProtocol
    private let addDroppedFiles: any AddDroppedFilesUseCaseProtocol

    init(useCases: UseCaseContainer) {
        fetchLibrary = useCases.fetchLibrary
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        loadThumbnail = useCases.loadThumbnail
        updateSlideshowConfig = useCases.updateSlideshowConfig
        setDirectory = useCases.setDirectory
        addDroppedFiles = useCases.addDroppedFiles
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        LibraryPickerViewModel(
            fetchLibrary: fetchLibrary,
            loadThumbnail: loadThumbnail,
            setDirectory: setDirectory,
            addDroppedFiles: addDroppedFiles
        )
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
            updateSlideshowConfig: updateSlideshowConfig
        )
    }
}
