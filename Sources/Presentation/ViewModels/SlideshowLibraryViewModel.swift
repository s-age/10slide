import Foundation
import Observation

@Observable
@MainActor
final class SlideshowLibraryViewModel {
    private(set) var slideshows: [Slideshow] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchSlideshowsUseCase: any FetchSlideshowsUseCaseProtocol

    init(fetchSlideshows: any FetchSlideshowsUseCaseProtocol) {
        self.fetchSlideshowsUseCase = fetchSlideshows
    }

    func loadLibrary() async {
        isLoading = true
        defer { isLoading = false }
        do {
            slideshows = try await fetchSlideshowsUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
