import Foundation
import Observation

@Observable
@MainActor
final class LibraryPickerViewModel {
    private(set) var identifiers: [String] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var thumbnails: [String: Data] = [:]

    private let fetchLibraryUseCase: any FetchLibraryUseCaseProtocol
    private let loadThumbnailUseCase: any LoadThumbnailUseCaseProtocol

    init(fetchLibrary: any FetchLibraryUseCaseProtocol, loadThumbnail: any LoadThumbnailUseCaseProtocol) {
        self.fetchLibraryUseCase = fetchLibrary
        self.loadThumbnailUseCase = loadThumbnail
    }

    func loadLibrary() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            identifiers = try await fetchLibraryUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadThumbnail(identifier: String) async {
        guard thumbnails[identifier] == nil else { return }
        if let data = try? await loadThumbnailUseCase.execute(localIdentifier: identifier) {
            thumbnails[identifier] = data
        }
    }
}
