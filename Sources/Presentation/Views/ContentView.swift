import SwiftUI

struct ContentView: View {
    @State private var libraryViewModel: LibraryViewModel
    @State private var thumbnailViewModel: ThumbnailViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    @State private var selectedSlideshow: Slideshow?

    private let makeSlideshowPlayerViewModel: @MainActor (Slideshow) -> SlideshowPlayerViewModel

    init(
        libraryViewModel: LibraryViewModel,
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        makeSlideshowPlayerViewModel: @escaping @MainActor (Slideshow) -> SlideshowPlayerViewModel
    ) {
        self._libraryViewModel = State(initialValue: libraryViewModel)
        self._thumbnailViewModel = State(initialValue: thumbnailViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self.makeSlideshowPlayerViewModel = makeSlideshowPlayerViewModel
    }

    var body: some View {
        if let slideshow = selectedSlideshow {
            SlideshowPlayerView(
                viewModel: makeSlideshowPlayerViewModel(slideshow),
                onBack: { selectedSlideshow = nil }
            )
        } else {
            LibraryPickerView(
                libraryViewModel: libraryViewModel,
                thumbnailViewModel: thumbnailViewModel,
                createViewModel: createViewModel,
                onSlideshowCreated: { slideshow in selectedSlideshow = slideshow }
            )
        }
    }
}
