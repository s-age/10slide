import SwiftUI

struct LibraryPickerView: View {
    @State private var libraryViewModel: LibraryPickerViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    var onSlideshowCreated: (Slideshow) -> Void

    init(
        libraryViewModel: LibraryPickerViewModel,
        createViewModel: CreateSlideshowViewModel,
        onSlideshowCreated: @escaping (Slideshow) -> Void
    ) {
        self._libraryViewModel = State(initialValue: libraryViewModel)
        self._createViewModel = State(initialValue: createViewModel)
        self.onSlideshowCreated = onSlideshowCreated
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            libraryStatusBanner

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(libraryViewModel.identifiers, id: \.self) { identifier in
                        PhotoCell(
                            thumbnailData: libraryViewModel.thumbnails[identifier],
                            isSelected: createViewModel.selectedIdentifiers.contains(identifier)
                        )
                        .onTapGesture {
                            toggleSelection(identifier)
                        }
                        .task(id: identifier) {
                            await libraryViewModel.loadThumbnail(identifier: identifier)
                        }
                    }
                }
                .padding()
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
            Picker("Duration", selection: $createViewModel.selectedDuration) {
                ForEach(SlideDuration.allCases, id: \.self) { duration in
                    Text(duration.displayLabel).tag(duration)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            Picker("Transition", selection: $createViewModel.selectedTransition) {
                ForEach(TransitionType.allCases, id: \.self) { transition in
                    Text(transition.rawValue.capitalized).tag(transition)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

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
    let thumbnailData: Data?
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let data = thumbnailData, let nsImage = NSImage(data: data) {
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
