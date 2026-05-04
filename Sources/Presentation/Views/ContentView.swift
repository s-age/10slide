import SwiftUI

struct ContentView: View {
    @State private var libraryViewModel: LibraryViewModel
    @State private var thumbnailViewModel: ThumbnailViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    @State private var selectedSlideshow: Slideshow?

    private let makeSlideshowPlayerViewModel: @MainActor (Slideshow) -> SlideshowPlayerViewModel
    private let makeSlideshowLibraryViewModel: @MainActor () -> SlideshowLibraryViewModel

    init(
        libraryViewModel: LibraryViewModel,
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        makeSlideshowPlayerViewModel: @escaping @MainActor (Slideshow) -> SlideshowPlayerViewModel,
        makeSlideshowLibraryViewModel: @escaping @MainActor () -> SlideshowLibraryViewModel
    ) {
        self._libraryViewModel = State(initialValue: libraryViewModel)
        self._thumbnailViewModel = State(initialValue: thumbnailViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self.makeSlideshowPlayerViewModel = makeSlideshowPlayerViewModel
        self.makeSlideshowLibraryViewModel = makeSlideshowLibraryViewModel
    }

    var body: some View {
        if let slideshow = selectedSlideshow {
            SlideshowPlayerView(
                viewModel: makeSlideshowPlayerViewModel(slideshow),
                onBack: { selectedSlideshow = nil }
            )
        } else {
            HomeView(
                libraryViewModel: libraryViewModel,
                thumbnailViewModel: thumbnailViewModel,
                createViewModel: createViewModel,
                slideshowLibraryViewModel: makeSlideshowLibraryViewModel(),
                onSlideshowSelected: { selectedSlideshow = $0 }
            )
        }
    }
}
