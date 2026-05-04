import SwiftUI

struct HomeView: View {
    @State private var thumbnailViewModel: ThumbnailViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    @State private var slideshowLibraryViewModel: SlideshowLibraryViewModel
    @State private var pendingEditSlideshow: Slideshow?
    @State private var showDiscardWorkDialog = false
    let onSlideshowSelected: (Slideshow) -> Void

    init(
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        slideshowLibraryViewModel: SlideshowLibraryViewModel,
        onSlideshowSelected: @escaping (Slideshow) -> Void
    ) {
        self._thumbnailViewModel = State(initialValue: thumbnailViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self._slideshowLibraryViewModel = State(initialValue: slideshowLibraryViewModel)
        self.onSlideshowSelected = onSlideshowSelected
    }

    var body: some View {
        GeometryReader { geometry in
            HSplitView {
                SlideshowLibraryPanel(
                    viewModel: slideshowLibraryViewModel,
                    onSelect: onSlideshowSelected,
                    onEdit: handleEdit
                )
                .frame(
                    minWidth: 200,
                    idealWidth: geometry.size.width * 0.3,
                    maxWidth: geometry.size.width * 0.3
                )

                LibraryPickerView(
                    thumbnailViewModel: thumbnailViewModel,
                    createViewModel: createViewModel,
                    onSlideshowCreated: { slideshow in
                        Task { await slideshowLibraryViewModel.loadLibrary() }
                        onSlideshowSelected(slideshow)
                    }
                )
                .frame(minWidth: 400)
            }
        }
        .alert("Discard current work?", isPresented: $showDiscardWorkDialog) {
            Button("Discard", role: .destructive) {
                if let slideshow = pendingEditSlideshow {
                    applyEdit(slideshow)
                }
                pendingEditSlideshow = nil
            }
            Button("Cancel", role: .cancel) {
                pendingEditSlideshow = nil
            }
        } message: {
            Text("Starting a new edit will clear your current photo selection and slideshow name.")
        }
    }

    private func handleEdit(_ slideshow: Slideshow) {
        if createViewModel.hasUnsavedWork {
            pendingEditSlideshow = slideshow
            showDiscardWorkDialog = true
        } else {
            applyEdit(slideshow)
        }
    }

    private func applyEdit(_ slideshow: Slideshow) {
        createViewModel.loadSlideshow(slideshow)
    }
}
