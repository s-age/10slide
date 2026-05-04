import SwiftUI

struct HomeView: View {
    @State private var libraryViewModel: LibraryViewModel
    @State private var thumbnailViewModel: ThumbnailViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    @State private var slideshowLibraryViewModel: SlideshowLibraryViewModel
    let onSlideshowSelected: (Slideshow) -> Void

    init(
        libraryViewModel: LibraryViewModel,
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        slideshowLibraryViewModel: SlideshowLibraryViewModel,
        onSlideshowSelected: @escaping (Slideshow) -> Void
    ) {
        self._libraryViewModel = State(initialValue: libraryViewModel)
        self._thumbnailViewModel = State(initialValue: thumbnailViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self._slideshowLibraryViewModel = State(initialValue: slideshowLibraryViewModel)
        self.onSlideshowSelected = onSlideshowSelected
    }

    var body: some View {
        HSplitView {
            LibraryPickerView(
                libraryViewModel: libraryViewModel,
                thumbnailViewModel: thumbnailViewModel,
                createViewModel: createViewModel,
                onSlideshowCreated: { slideshow in
                    Task { await slideshowLibraryViewModel.loadLibrary() }
                    onSlideshowSelected(slideshow)
                }
            )
            .frame(minWidth: 400)

            SlideshowLibraryPanel(
                viewModel: slideshowLibraryViewModel,
                onSelect: onSlideshowSelected
            )
            .frame(minWidth: 200, idealWidth: 260)
        }
    }
}
