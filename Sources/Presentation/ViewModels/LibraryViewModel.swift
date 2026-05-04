import Foundation
import Observation

@Observable
@MainActor
final class LibraryViewModel {
    private(set) var identifiers: [String] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var currentDirectoryName: String = "Desktop"

    private let fetchLibraryUseCase: any FetchLibraryUseCaseProtocol
    private let setDirectoryUseCase: any SetDirectoryUseCaseProtocol
    private let addDroppedFilesUseCase: any AddDroppedFilesUseCaseProtocol

    init(
        fetchLibrary: any FetchLibraryUseCaseProtocol,
        setDirectory: any SetDirectoryUseCaseProtocol,
        addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    ) {
        self.fetchLibraryUseCase = fetchLibrary
        self.setDirectoryUseCase = setDirectory
        self.addDroppedFilesUseCase = addDroppedFiles
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

    func setDirectory(_ url: URL) async {
        await setDirectoryUseCase.execute(url: url)
        currentDirectoryName = url.lastPathComponent
        await loadLibrary()
    }

    func addDroppedFiles(_ urls: [URL]) {
        let newPaths = addDroppedFilesUseCase.execute(urls: urls, existingIdentifiers: identifiers)
        identifiers.append(contentsOf: newPaths)
    }
}
