final class PresentationContainer {
    let makeLibraryPicker: @MainActor () -> LibraryPickerViewModel
    let makeCreateSlideshow: @MainActor () -> CreateSlideshowViewModel
    let makePlayer: @MainActor (Slideshow) -> SlideshowPlayerViewModel

    init(useCases: UseCaseContainer) {
        let fetchLibrary = useCases.fetchLibrary
        let createSlideshow = useCases.createSlideshow
        let loadSlideImage = useCases.loadSlideImage

        makeLibraryPicker = {
            LibraryPickerViewModel(fetchLibrary: fetchLibrary)
        }
        makeCreateSlideshow = {
            CreateSlideshowViewModel(createSlideshow: createSlideshow)
        }
        makePlayer = { slideshow in
            SlideshowPlayerViewModel(
                slideshow: slideshow,
                loadSlideImage: loadSlideImage
            )
        }
    }
}
