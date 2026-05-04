import Foundation
import Observation

@Observable
@MainActor
final class CreateSlideshowViewModel {
    private(set) var selectedIdentifiers: Set<String> = []
    var slideshowName: String = ""
    var selectedDuration: SlideDuration = .five
    var selectedTransition: TransitionType = .fade
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let createSlideshowUseCase: any CreateSlideshowUseCaseProtocol

    init(createSlideshow: any CreateSlideshowUseCaseProtocol) {
        self.createSlideshowUseCase = createSlideshow
    }

    func toggleSelection(_ identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            selectedIdentifiers.remove(identifier)
        } else {
            selectedIdentifiers.insert(identifier)
        }
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
                localIdentifiers: Array(selectedIdentifiers),
                config: config
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
