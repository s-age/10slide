import Foundation
import Observation

@Observable
@MainActor
final class CreateSlideshowViewModel {
    var selectedIdentifiers: Set<String> = []
    var slideshowName: String = ""
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let createSlideshowUseCase: any CreateSlideshowUseCaseProtocol

    init(createSlideshow: any CreateSlideshowUseCaseProtocol) {
        self.createSlideshowUseCase = createSlideshow
    }

    func createSlideshow() async -> Slideshow? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await createSlideshowUseCase.execute(
                name: slideshowName,
                localIdentifiers: Array(selectedIdentifiers)
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
