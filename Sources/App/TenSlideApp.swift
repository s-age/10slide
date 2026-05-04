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
                libraryViewModel: container.presentation.makeLibraryPickerViewModel(),
                createViewModel: container.presentation.makeCreateSlideshowViewModel(),
                makeSlideshowPlayerViewModel: container.presentation.makeSlideshowPlayerViewModel
            )
        }
        .modelContainer(container.infrastructure.modelContainer)
    }
}
