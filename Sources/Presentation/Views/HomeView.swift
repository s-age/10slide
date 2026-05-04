import SwiftUI

struct HomeView: View {
    private let thumbnailViewModel: ThumbnailViewModel
    private let createViewModel: CreateSlideshowViewModel
    private let slideshowLibraryViewModel: SlideshowLibraryViewModel
    @State private var pendingEditSlideshow: Slideshow?
    @State private var pendingNewSlideshow = false
    @State private var showDiscardWorkDialog = false
    let onSlideshowSelected: (Slideshow) -> Void

    init(
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        slideshowLibraryViewModel: SlideshowLibraryViewModel,
        onSlideshowSelected: @escaping (Slideshow) -> Void
    ) {
        self.thumbnailViewModel = thumbnailViewModel
        self.createViewModel = createViewModel
        self.slideshowLibraryViewModel = slideshowLibraryViewModel
        self.onSlideshowSelected = onSlideshowSelected
    }

    var body: some View {
        GeometryReader { geometry in
            HSplitView {
                SlideshowLibraryPanel(
                    viewModel: slideshowLibraryViewModel,
                    onSelect: onSlideshowSelected,
                    onEdit: handleEdit,
                    onCreate: handleNewSlideshow
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
                if pendingNewSlideshow {
                    createViewModel.reset()
                    pendingNewSlideshow = false
                } else if let slideshow = pendingEditSlideshow {
                    applyEdit(slideshow)
                    pendingEditSlideshow = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingEditSlideshow = nil
                pendingNewSlideshow = false
            }
        } message: {
            Text("Starting a new edit will clear your current photo selection and slideshow name.")
        }
    }

    private func handleNewSlideshow() {
        if createViewModel.hasUnsavedWork {
            pendingNewSlideshow = true
            showDiscardWorkDialog = true
        } else {
            createViewModel.reset()
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
