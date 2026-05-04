import SwiftUI

struct SlideshowLibraryPanel: View {
    @State private var viewModel: SlideshowLibraryViewModel
    @State private var slideshowPendingDelete: Slideshow?
    let onSelect: (Slideshow) -> Void
    let onEdit: (Slideshow) -> Void
    let onCreate: () -> Void

    init(
        viewModel: SlideshowLibraryViewModel,
        onSelect: @escaping (Slideshow) -> Void,
        onEdit: @escaping (Slideshow) -> Void,
        onCreate: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onCreate = onCreate
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Library")
                    .font(.headline)
                Spacer()
                Button { onCreate() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
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
                    HStack {
                        Button { onSelect(slideshow) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slideshow.name).fontWeight(.medium)
                                Text("\(slideshow.slides.count) slides · \(slideshow.config.duration.displayLabel)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button { onSelect(slideshow) } label: {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.borderless)

                        Button { onEdit(slideshow) } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)

                        Button { slideshowPendingDelete = slideshow } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .task { await viewModel.loadLibrary() }
        .confirmationDialog(
            "Delete \"\(slideshowPendingDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { slideshowPendingDelete != nil },
                set: { if !$0 { slideshowPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let slideshow = slideshowPendingDelete {
                    Task { await viewModel.deleteSlideshow(id: slideshow.id) }
                }
                slideshowPendingDelete = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}
