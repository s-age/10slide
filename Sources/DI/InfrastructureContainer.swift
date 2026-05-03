import Foundation
import SwiftData

final class InfrastructureContainer {
    enum Error: Swift.Error { case missingApplicationSupportDirectory }

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
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw Error.missingApplicationSupportDirectory
        }
        configDataSource = ConfigStore(fileURL: appSupport.appendingPathComponent("10slide/config.yml"))
    }
}
