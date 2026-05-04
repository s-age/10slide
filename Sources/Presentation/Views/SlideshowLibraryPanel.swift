import SwiftUI

struct SlideshowLibraryPanel: View {
    @State private var viewModel: SlideshowLibraryViewModel
    let onSelect: (Slideshow) -> Void

    init(viewModel: SlideshowLibraryViewModel, onSelect: @escaping (Slideshow) -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Library")
                .font(.headline)
                .padding(.vertical, 8)
            Divider()
            if viewModel.isLoading {
                ProgressView().padding()
            } else if viewModel.slideshows.isEmpty {
                ContentUnavailableView(
                    "No Slideshows",
                    systemImage: "photo.on.rectangle",
                    description: Text("Create a slideshow to see it here.")
                )
            } else {
                List(viewModel.slideshows) { slideshow in
                    Button { onSelect(slideshow) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slideshow.name).fontWeight(.medium)
                            Text("\(slideshow.slides.count) slides · \(slideshow.config.duration.displayLabel)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task { await viewModel.loadLibrary() }
    }
}
