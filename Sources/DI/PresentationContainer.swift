final class PresentationContainer {
    private let fetchLibrary: any FetchLibraryUseCaseProtocol
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol

    init(useCases: UseCaseContainer) {
        fetchLibrary = useCases.fetchLibrary
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        LibraryPickerViewModel(fetchLibrary: fetchLibrary)
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
