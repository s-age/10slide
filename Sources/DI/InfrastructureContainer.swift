import Foundation
import SwiftData

final class InfrastructureContainer {
    enum Error: Swift.Error { case missingApplicationSupportDirectory }

    let modelContainer: ModelContainer
    let swiftDataStore: any SwiftDataStoreProtocol
    let imageDataSource: any ImageDataSourceProtocol
    let configDataSource: any ConfigDataSourceProtocol

    init() throws {
        modelContainer = try ModelContainer(for: SlideshowModel.self, SlideModel.self)
        swiftDataStore = SwiftDataStore(modelContainer: modelContainer)
        imageDataSource = FileSystemImageDataSource()
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            throw Error.missingApplicationSupportDirectory
        }
        configDataSource = ConfigStore(fileURL: appSupport.appendingPathComponent("10slide/config.yml"))
    }
}
