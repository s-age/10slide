import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ThumbnailViewModel {
    private(set) var images: [String: NSImage] = [:]

    private let loadThumbnail: LoadThumbnailUseCaseProtocol

    init(loadThumbnail: LoadThumbnailUseCaseProtocol) {
        self.loadThumbnail = loadThumbnail
    }

    func load(identifier: String) async {
        guard images[identifier] == nil else { return }
        let request = LoadThumbnailRequest(localIdentifier: identifier)
        guard let data = try? await loadThumbnail.execute(request) else { return }
        images[identifier] = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
    }
}
