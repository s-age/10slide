import SwiftUI

struct ContentView: View {
    @State private var libraryViewModel: LibraryPickerViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    @State private var selectedSlideshow: Slideshow?

    private let makeSlideshowPlayerViewModel: @MainActor (Slideshow) -> SlideshowPlayerViewModel

    init(
        libraryViewModel: LibraryPickerViewModel,
        createViewModel: CreateSlideshowViewModel,
        makeSlideshowPlayerViewModel: @escaping @MainActor (Slideshow) -> SlideshowPlayerViewModel
    ) {
        self._libraryViewModel = State(initialValue: libraryViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self.makeSlideshowPlayerViewModel = makeSlideshowPlayerViewModel
    }

    var body: some View {
        if let slideshow = selectedSlideshow {
            SlideshowPlayerView(viewModel: makeSlideshowPlayerViewModel(slideshow))
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button("Back") { selectedSlideshow = nil }
                    }
                }
        } else {
            LibraryPickerView(
                libraryViewModel: libraryViewModel,
                createViewModel: createViewModel,
                onSlideshowCreated: { slideshow in selectedSlideshow = slideshow }
            )
        }
    }
}
