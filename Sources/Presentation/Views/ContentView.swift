import SwiftUI

struct ContentView: View {
    private let thumbnailViewModel: ThumbnailViewModel
    private let createViewModel: CreateSlideshowViewModel
    @State private var selectedSlideshow: SlideshowResponse?
    @State private var spritePanel: SpritePanel?

    private let makeSlideshowPlayerViewModel: @MainActor @Sendable (SlideshowResponse) -> SlideshowPlayerViewModel
    private let makeSpritePlayerViewModel: @MainActor @Sendable (SlideshowResponse, Int) -> SlideshowPlayerViewModel
    private let makeSlideshowLibraryViewModel: @MainActor @Sendable () -> SlideshowLibraryViewModel

    init(
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        makeSlideshowPlayerViewModel: @escaping @MainActor @Sendable (SlideshowResponse) -> SlideshowPlayerViewModel,
        makeSpritePlayerViewModel: @escaping @MainActor @Sendable (SlideshowResponse, Int) -> SlideshowPlayerViewModel,
        makeSlideshowLibraryViewModel: @escaping @MainActor @Sendable () -> SlideshowLibraryViewModel
    ) {
        self.thumbnailViewModel = thumbnailViewModel
        self.createViewModel = createViewModel
        self.makeSlideshowPlayerViewModel = makeSlideshowPlayerViewModel
        self.makeSpritePlayerViewModel = makeSpritePlayerViewModel
        self.makeSlideshowLibraryViewModel = makeSlideshowLibraryViewModel
    }

    var body: some View {
        Group {
            if let slideshow = selectedSlideshow {
                SlideshowPlayerView(
                    viewModel: makeSlideshowPlayerViewModel(slideshow),
                    thumbnailViewModel: thumbnailViewModel,
                    onBack: { selectedSlideshow = nil },
                    onSpriteMode: { startIndex in openSpriteMode(slideshow: slideshow, startIndex: startIndex) }
                )
                .navigationTitle(slideshow.name)
            } else {
                HomeView(
                    thumbnailViewModel: thumbnailViewModel,
                    createViewModel: createViewModel,
                    slideshowLibraryViewModel: makeSlideshowLibraryViewModel(),
                    onSlideshowSelected: { selectedSlideshow = $0 }
                )
                .navigationTitle("")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let panel = notification.object as? SpritePanel, panel === spritePanel {
                spritePanel = nil
            }
        }
    }

    private func openSpriteMode(slideshow: SlideshowResponse, startIndex: Int) {
        spritePanel?.close()
        let viewModel = makeSpritePlayerViewModel(slideshow, startIndex)
        spritePanel = SpritePanel.open { panel in
            SlideshowPlayerView(
                viewModel: viewModel,
                thumbnailViewModel: thumbnailViewModel,
                onBack: { [weak panel] in panel?.close() }
            )
        }
        selectedSlideshow = nil
    }
}
