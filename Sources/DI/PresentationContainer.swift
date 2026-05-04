final class PresentationContainer {
    private let fetchLibrary: any FetchLibraryUseCaseProtocol
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol
    private let loadThumbnail: any LoadThumbnailUseCaseProtocol

    init(useCases: UseCaseContainer) {
        fetchLibrary = useCases.fetchLibrary
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        loadThumbnail = useCases.loadThumbnail
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        LibraryPickerViewModel(fetchLibrary: fetchLibrary, loadThumbnail: loadThumbnail)
    }

    @MainActor
    func makeCreateSlideshowViewModel() -> CreateSlideshowViewModel {
        CreateSlideshowViewModel(createSlideshow: createSlideshow)
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: Slideshow) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(slideshow: slideshow, loadSlideImage: loadSlideImage)
    }
}
