import SwiftData

final class InfrastructureContainer {
    let modelContainer: ModelContainer
    let imageDataSource: any ImageDataSourceProtocol
    let slideDataSource: any SlideDataSourceProtocol

    init() throws {
        modelContainer = try ModelContainer(for: SlideModel.self, SlideshowModel.self)
        imageDataSource = ImageDataSource()
        slideDataSource = SlideDataSource(container: modelContainer)
    }
}
