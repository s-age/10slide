import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ThumbnailViewModel {
    private(set) var thumbnails: [String: Data] = [:]
    private(set) var images: [String: NSImage] = [:]

    private let loadThumbnailUseCase: LoadThumbnailUseCaseProtocol

    init(loadThumbnail: LoadThumbnailUseCaseProtocol) {
        self.loadThumbnailUseCase = loadThumbnail
    }

    func loadThumbnail(identifier: String) async {
        guard thumbnails[identifier] == nil else { return }
        let request = LoadThumbnailRequest(localIdentifier: identifier)
        guard let data = try? await loadThumbnailUseCase.execute(request) else { return }
        thumbnails[identifier] = data
        images[identifier] = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
    }
}
