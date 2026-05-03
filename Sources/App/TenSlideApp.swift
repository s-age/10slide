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
            ContentView()
        }
        .modelContainer(container.infrastructure.modelContainer)
    }
}
