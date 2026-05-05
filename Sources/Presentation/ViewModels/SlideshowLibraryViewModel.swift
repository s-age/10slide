import Foundation
import Observation

@Observable
@MainActor
final class SlideshowLibraryViewModel {
    private(set) var slideshows: [SlideshowResponse] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchSlideshows: FetchSlideshowsUseCaseProtocol
    private let deleteSlideshow: DeleteSlideshowUseCaseProtocol

    init(
        fetchSlideshows: FetchSlideshowsUseCaseProtocol,
        deleteSlideshow: DeleteSlideshowUseCaseProtocol
    ) {
        self.fetchSlideshows = fetchSlideshows
        self.deleteSlideshow = deleteSlideshow
    }

    func dismissError() {
        errorMessage = nil
    }

    func loadLibrary() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            slideshows = try await fetchSlideshows.execute(FetchSlideshowsRequest())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(id: UUID) async {
        do {
            try await deleteSlideshow.execute(DeleteSlideshowRequest(id: id))
            slideshows.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
