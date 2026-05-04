import SwiftUI
import SwiftData

@main
struct TenSlideApp: App {
    private let container: Container

    init() {
        do {
            container = try Container()
        } catch {
            fatalError("DI initialization failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                libraryViewModel: container.presentation.makeLibraryViewModel(),
                thumbnailViewModel: container.presentation.makeThumbnailViewModel(),
                createViewModel: container.presentation.makeCreateSlideshowViewModel(),
                makeSlideshowPlayerViewModel: container.presentation.makeSlideshowPlayerViewModel,
                makeSlideshowLibraryViewModel: container.presentation.makeSlideshowLibraryViewModel
            )
        }
        .modelContainer(container.infrastructure.modelContainer)
    }
}
