import Foundation
import Observation

@Observable
@MainActor
final class CreateSlideshowViewModel {
    private(set) var selectedIdentifiers: [String] = []
    var slideshowName: String = ""
    var selectedDuration: SlideDuration = .five
    var selectedTransition: TransitionType = .fade
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var editingSlideshow: Slideshow?

    private let createSlideshowUseCase: any CreateSlideshowUseCaseProtocol
    private let updateSlideshowUseCase: any UpdateSlideshowUseCaseProtocol
    private let addDroppedFilesUseCase: any AddDroppedFilesUseCaseProtocol

    init(
        createSlideshow: any CreateSlideshowUseCaseProtocol,
        updateSlideshow: any UpdateSlideshowUseCaseProtocol,
        addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    ) {
        self.createSlideshowUseCase = createSlideshow
        self.updateSlideshowUseCase = updateSlideshow
        self.addDroppedFilesUseCase = addDroppedFiles
    }

    var isEditing: Bool { editingSlideshow != nil }

    var hasUnsavedWork: Bool {
        !slideshowName.isEmpty || !selectedIdentifiers.isEmpty
    }

    func loadSlideshow(_ slideshow: Slideshow) {
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
        let newPaths = addDroppedFilesUseCase.execute(urls: urls, existingIdentifiers: selectedIdentifiers)
        selectedIdentifiers.append(contentsOf: newPaths)
    }

    func removeFile(_ identifier: String) {
        selectedIdentifiers.removeAll { $0 == identifier }
    }

    func saveSlideshow() async -> Slideshow? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if let existing = editingSlideshow {
                return try await updateSlideshowUseCase.execute(
                    slideshow: existing,
                    name: slideshowName,
                    localIdentifiers: selectedIdentifiers
                )
            } else {
                let config = SlideshowConfig(
                    duration: selectedDuration,
                    transition: selectedTransition,
                    loop: true
                )
                return try await createSlideshowUseCase.execute(
                    name: slideshowName,
                    localIdentifiers: selectedIdentifiers,
                    config: config
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
