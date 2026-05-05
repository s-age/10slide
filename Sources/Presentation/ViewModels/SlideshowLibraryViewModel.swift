import Foundation
import Observation

@Observable
@MainActor
final class SlideshowLibraryViewModel {
    private(set) var slideshows: [SlideshowResponse] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchSlideshowsUseCase: any FetchSlideshowsUseCaseProtocol
    private let deleteSlideshowUseCase: any DeleteSlideshowUseCaseProtocol

    init(
        fetchSlideshows: any FetchSlideshowsUseCaseProtocol,
        deleteSlideshow: any DeleteSlideshowUseCaseProtocol
    ) {
        self.fetchSlideshowsUseCase = fetchSlideshows
        self.deleteSlideshowUseCase = deleteSlideshow
    }

    func loadLibrary() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            slideshows = try await fetchSlideshowsUseCase.execute(FetchSlideshowsRequest())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSlideshow(id: UUID) async {
        do {
            try await deleteSlideshowUseCase.execute(DeleteSlideshowRequest(id: id))
            slideshows.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
