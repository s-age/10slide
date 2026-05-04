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

    private let createSlideshowUseCase: any CreateSlideshowUseCaseProtocol
    private let addDroppedFilesUseCase: any AddDroppedFilesUseCaseProtocol

    init(createSlideshow: any CreateSlideshowUseCaseProtocol, addDroppedFiles: any AddDroppedFilesUseCaseProtocol) {
        self.createSlideshowUseCase = createSlideshow
        self.addDroppedFilesUseCase = addDroppedFiles
    }

    var hasUnsavedWork: Bool {
        !slideshowName.isEmpty || !selectedIdentifiers.isEmpty
    }

    func loadSlideshow(_ slideshow: Slideshow) {
        slideshowName = slideshow.name
        selectedIdentifiers = slideshow.slides.map(\.localIdentifier)
    }

    func reset() {
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

    func createSlideshow() async -> Slideshow? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let config = SlideshowConfig(
            duration: selectedDuration,
            transition: selectedTransition,
            loop: true
        )
        do {
            return try await createSlideshowUseCase.execute(
                name: slideshowName,
                localIdentifiers: selectedIdentifiers,
                config: config
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
