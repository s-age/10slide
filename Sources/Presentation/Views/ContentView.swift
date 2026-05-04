import SwiftUI

struct ContentView: View {
    private let thumbnailViewModel: ThumbnailViewModel
    private let createViewModel: CreateSlideshowViewModel
    @State private var selectedSlideshow: Slideshow?

    private let makeSlideshowPlayerViewModel: @MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel
    private let makeSlideshowLibraryViewModel: @MainActor @Sendable () -> SlideshowLibraryViewModel

    init(
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        makeSlideshowPlayerViewModel: @escaping @MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel,
        makeSlideshowLibraryViewModel: @escaping @MainActor @Sendable () -> SlideshowLibraryViewModel
    ) {
        self.thumbnailViewModel = thumbnailViewModel
        self.createViewModel = createViewModel
        self.makeSlideshowPlayerViewModel = makeSlideshowPlayerViewModel
        self.makeSlideshowLibraryViewModel = makeSlideshowLibraryViewModel
    }

    var body: some View {
        if let slideshow = selectedSlideshow {
            SlideshowPlayerView(
                viewModel: makeSlideshowPlayerViewModel(slideshow),
                thumbnailViewModel: thumbnailViewModel,
                onBack: { selectedSlideshow = nil }
            )
        } else {
            HomeView(
                thumbnailViewModel: thumbnailViewModel,
                createViewModel: createViewModel,
                slideshowLibraryViewModel: makeSlideshowLibraryViewModel(),
                onSlideshowSelected: { selectedSlideshow = $0 }
            )
        }
    }
}
