import SwiftUI

struct LibraryPickerView: View {
    private let thumbnailViewModel: ThumbnailViewModel
    @Bindable var createViewModel: CreateSlideshowViewModel
    var onSlideshowCreated: (SlideshowResponse) -> Void

    init(
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        onSlideshowCreated: @escaping (SlideshowResponse) -> Void
    ) {
        self.thumbnailViewModel = thumbnailViewModel
        self.createViewModel = createViewModel
        self.onSlideshowCreated = onSlideshowCreated
    }

    @State private var isShowingFilePicker = false
    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 100

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize), spacing: 8)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if createViewModel.selectedIdentifiers.isEmpty {
                    dropPlaceholder
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(createViewModel.selectedIdentifiers, id: \.self) { identifier in
                                PhotoCell(
                                    image: thumbnailViewModel.images[identifier],
                                    onRemove: { createViewModel.removeFile(identifier) }
                                )
                                .task(id: identifier) {
                                    await thumbnailViewModel.load(identifier: identifier)
                                }
                            }
                        }
                        .padding()
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Slider(value: $thumbnailSize, in: 60...180, step: 10)
                            .frame(width: 120)
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .padding(12)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self) { urls, _ in
                createViewModel.addFiles(urls)
                return !urls.isEmpty
            }

            if let error = createViewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()
            bottomBar
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            guard let urls = try? result.get() else { return }
            createViewModel.addFiles(urls)
        }
    }

    private var dropPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drop images here or use Browse")
                .foregroundStyle(.secondary)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Browse…") {
                isShowingFilePicker = true
            }

            TextField("Slideshow name", text: $createViewModel.slideshowName)
                .textFieldStyle(.roundedBorder)

            Button(createViewModel.isEditing ? "Update" : "Create") {
                Task {
                    if let slideshow = await createViewModel.saveSlideshow() {
                        onSlideshowCreated(slideshow)
                    }
                }
            }
            .disabled(
                createViewModel.slideshowName.isEmpty ||
                createViewModel.selectedIdentifiers.isEmpty ||
                createViewModel.isLoading
            )
        }
        .padding()
    }
}

// MARK: - PhotoCell

private struct PhotoCell: View {
    let image: NSImage?
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            Color.gray.opacity(0.15)
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topTrailing) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, Color.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }
}
