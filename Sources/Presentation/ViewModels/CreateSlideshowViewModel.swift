import Foundation
import Observation

@Observable
@MainActor
final class CreateSlideshowViewModel {
    private(set) var selectedIdentifiers: [String] = []
    var slideshowName: String = ""
    var selectedDuration: SlideDurationResponse = .five
    var selectedTransition: TransitionTypeResponse = .fade
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var editingSlideshow: SlideshowResponse?

    private let createSlideshowUseCase: CreateSlideshowUseCaseProtocol
    private let updateSlideshowUseCase: UpdateSlideshowUseCaseProtocol
    private let addDroppedFilesUseCase: AddDroppedFilesUseCaseProtocol

    init(
        createSlideshow: CreateSlideshowUseCaseProtocol,
        updateSlideshow: UpdateSlideshowUseCaseProtocol,
        addDroppedFiles: AddDroppedFilesUseCaseProtocol
    ) {
        self.createSlideshowUseCase = createSlideshow
        self.updateSlideshowUseCase = updateSlideshow
        self.addDroppedFilesUseCase = addDroppedFiles
    }

    var isEditing: Bool { editingSlideshow != nil }

    var hasUnsavedWork: Bool {
        !slideshowName.isEmpty || !selectedIdentifiers.isEmpty
    }

    func loadSlideshow(_ slideshow: SlideshowResponse) {
        editingSlideshow = slideshow
        slideshowName = slideshow.name
        selectedIdentifiers = slideshow.slides.map(\.localIdentifier)
    }

    func reset() {
        editingSlideshow = nil
        slideshowName = ""
        selectedIdentifiers = []
    }

    func addFiles(_ urls: [URL]) {
        let request = AddDroppedFilesRequest(
            urls: urls,
            existingIdentifiers: selectedIdentifiers
        )
        // validate() is empty; file-path filtering is best-effort — no user-actionable error
        guard let newPaths = try? addDroppedFilesUseCase.execute(request) else { return }
        selectedIdentifiers.append(contentsOf: newPaths)
    }

    func removeFile(_ identifier: String) {
        selectedIdentifiers.removeAll { $0 == identifier }
    }

    func dismissError() {
        errorMessage = nil
    }

    func saveSlideshow() async -> SlideshowResponse? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let existing = editingSlideshow {
                let request = UpdateSlideshowRequest(
                    id: existing.id,
                    name: slideshowName,
                    localIdentifiers: selectedIdentifiers
                )
                return try await updateSlideshowUseCase.execute(request)
            } else {
                let request = CreateSlideshowRequest(
                    name: slideshowName,
                    localIdentifiers: selectedIdentifiers,
                    duration: selectedDuration,
                    transition: selectedTransition,
                    loop: true
                )
                return try await createSlideshowUseCase.execute(request)
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
