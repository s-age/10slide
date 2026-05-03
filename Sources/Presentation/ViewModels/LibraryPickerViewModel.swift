import Foundation
import Observation

@Observable
@MainActor
final class LibraryPickerViewModel {
    private(set) var identifiers: [String] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchLibraryUseCase: any FetchLibraryUseCaseProtocol

    init(fetchLibrary: any FetchLibraryUseCaseProtocol) {
        self.fetchLibraryUseCase = fetchLibrary
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
}
