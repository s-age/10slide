import SwiftUI

struct LibraryPickerView: View {
    @State private var libraryViewModel: LibraryViewModel
    @State private var thumbnailViewModel: ThumbnailViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    var onSlideshowCreated: (Slideshow) -> Void

    init(
        libraryViewModel: LibraryViewModel,
        thumbnailViewModel: ThumbnailViewModel,
        createViewModel: CreateSlideshowViewModel,
        onSlideshowCreated: @escaping (Slideshow) -> Void
    ) {
        self._libraryViewModel = State(initialValue: libraryViewModel)
        self._thumbnailViewModel = State(initialValue: thumbnailViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self.onSlideshowCreated = onSlideshowCreated
    }

    @State private var isShowingFolderPicker = false
    @State private var decodedImages: [String: NSImage] = [:]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            directoryBar
            libraryStatusBanner

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(libraryViewModel.identifiers, id: \.self) { identifier in
                        PhotoCell(
                            image: decodedImages[identifier],
                            isSelected: createViewModel.selectedIdentifiers.contains(identifier)
                        )
                        .onTapGesture {
                            toggleSelection(identifier)
                        }
                        .task(id: identifier) {
                            await thumbnailViewModel.loadThumbnail(identifier: identifier)
                            if let data = thumbnailViewModel.thumbnails[identifier] {
                                decodedImages[identifier] = await Task.detached(priority: .userInitiated) {
                                    NSImage(data: data)
                                }.value
                            }
                        }
                    }
                }
                .padding()
                .dropDestination(for: URL.self) { urls, _ in
                    libraryViewModel.addDroppedFiles(urls)
                    return !urls.isEmpty
                }
            }

            if let error = createViewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            bottomBar
        }
        .task { await libraryViewModel.loadLibrary() }
        .fileImporter(
            isPresented: $isShowingFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            guard let url = try? result.get() else { return }
            Task { await libraryViewModel.setDirectory(url) }
        }
    }

    private var directoryBar: some View {
        HStack {
            Label(libraryViewModel.currentDirectoryName, systemImage: "folder")
                .font(.subheadline)
            Spacer()
            Button("Select Folder…") {
                isShowingFolderPicker = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private var libraryStatusBanner: some View {
        if libraryViewModel.isLoading {
            ProgressView("Loading library…")
                .padding()
        } else if let error = libraryViewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .padding()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            TextField("Slideshow name", text: $createViewModel.slideshowName)
                .textFieldStyle(.roundedBorder)

            Button("Create") {
                Task {
                    if let slideshow = await createViewModel.createSlideshow() {
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

    private func toggleSelection(_ identifier: String) {
        createViewModel.toggleSelection(identifier)
    }
}

// MARK: - PhotoCell

private struct PhotoCell: View {
    let image: NSImage?
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let nsImage = image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .frame(height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 3
                )
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(6)
            }
        }
    }
}
