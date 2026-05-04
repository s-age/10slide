import Foundation
import Observation

@Observable
@MainActor
final class LibraryPickerViewModel {
    private(set) var identifiers: [String] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?
    private(set) var thumbnails: [String: Data] = [:]
    private(set) var currentDirectoryName: String = "Desktop"

    private let fetchLibraryUseCase: any FetchLibraryUseCaseProtocol
    private let loadThumbnailUseCase: any LoadThumbnailUseCaseProtocol
    private let setDirectoryUseCase: any SetDirectoryUseCaseProtocol
    private let addDroppedFilesUseCase: any AddDroppedFilesUseCaseProtocol

    init(
        fetchLibrary: any FetchLibraryUseCaseProtocol,
        loadThumbnail: any LoadThumbnailUseCaseProtocol,
        setDirectory: any SetDirectoryUseCaseProtocol,
        addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    ) {
        self.fetchLibraryUseCase = fetchLibrary
        self.loadThumbnailUseCase = loadThumbnail
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

    func loadThumbnail(identifier: String) async {
        guard thumbnails[identifier] == nil else { return }
        if let data = try? await loadThumbnailUseCase.execute(localIdentifier: identifier) {
            thumbnails[identifier] = data
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
