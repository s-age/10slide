import Foundation
import SwiftData

final class InfrastructureContainer {
    let modelContainer: ModelContainer
    let imageDataSource: any ImageDataSourceProtocol
    let slideDataSource: any SlideDataSourceProtocol
    let slideshowDataSource: any SlideshowDataSourceProtocol
    let configDataSource: any ConfigDataSourceProtocol

    init() throws {
        modelContainer = try ModelContainer(for: SlideModel.self, SlideshowModel.self)
        imageDataSource = ImageDataSource()
        slideDataSource = SlideDataSource(container: modelContainer)
        slideshowDataSource = SlideshowDataSource(container: modelContainer)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        configDataSource = ConfigStore(fileURL: appSupport.appendingPathComponent("10slide/config.yml"))
    }
}
