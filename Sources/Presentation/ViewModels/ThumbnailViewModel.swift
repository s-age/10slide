import Foundation
import Observation

@Observable
@MainActor
final class ThumbnailViewModel {
    private(set) var thumbnails: [String: Data] = [:]

    private let loadThumbnailUseCase: any LoadThumbnailUseCaseProtocol

    init(loadThumbnail: any LoadThumbnailUseCaseProtocol) {
        self.loadThumbnailUseCase = loadThumbnail
    }

    func loadThumbnail(identifier: String) async {
        guard thumbnails[identifier] == nil else { return }
        if let data = try? await loadThumbnailUseCase.execute(localIdentifier: identifier) {
            thumbnails[identifier] = data
        }
    }
}
