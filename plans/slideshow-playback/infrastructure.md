# Infrastructure Layer

## `Sources/Infrastructure/Protocols/ConfigDataSourceProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol ConfigDataSourceProtocol: Sendable {
    func load() async throws -> ConfigDTO
    func save(_ dto: ConfigDTO) async throws
}
```

## `Sources/Infrastructure/Protocols/SlideshowDataSourceProtocol.swift` (new)

**Protocol**:
```swift
import Foundation

protocol SlideshowDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideshowModel]
    func fetch(id: UUID) async throws -> SlideshowModel?
    func save(_ model: SlideshowModel) async throws
    func delete(id: UUID) async throws
}
```

## `Sources/Infrastructure/Config/DTO/ConfigDTO.swift` (new)

**Struct**:
```swift
import Foundation

struct ConfigDTO: Sendable, Codable {
    var defaultDuration: TimeInterval
    var transition: String
    var loop: Bool
}
```

## `Sources/Infrastructure/Config/ConfigStore.swift` (new)

**Implements**: ConfigDataSourceProtocol

```swift
import Foundation
import Yams

actor ConfigStore: ConfigDataSourceProtocol {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> ConfigDTO {
        // Read YAML from fileURL, decode with YAMLDecoder
        // Return default ConfigDTO if file does not exist
    }

    func save(_ dto: ConfigDTO) async throws {
        // Encode with YAMLEncoder, write to fileURL
        // Create parent directory if needed
    }
}
```

## `Sources/Infrastructure/SwiftData/DTO/SlideshowModel.swift` (modified)

**Change**: Add config fields with defaults.

```swift
import SwiftData
import Foundation

@Model
final class SlideshowModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var defaultDuration: TimeInterval
    var transitionRawValue: String
    var loop: Bool
    @Relationship(deleteRule: .cascade, inverse: \SlideModel.slideshow)
    var slides: [SlideModel]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        defaultDuration: TimeInterval = 5.0,
        transitionRawValue: String = "fade",
        loop: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.defaultDuration = defaultDuration
        self.transitionRawValue = transitionRawValue
        self.loop = loop
        self.slides = []
    }
}
```

## `Sources/Infrastructure/SwiftData/SlideshowDataSource.swift` (new)

**Implements**: SlideshowDataSourceProtocol

```swift
import Foundation
import SwiftData

final class SlideshowDataSource: SlideshowDataSourceProtocol {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [SlideshowModel] { ... }
    func fetch(id: UUID) async throws -> SlideshowModel? { ... }
    func save(_ model: SlideshowModel) async throws { ... }
    func delete(id: UUID) async throws { ... }
}
```

## `Sources/Infrastructure/Image/ImageDataSource.swift` (modified)

**Change**: Implement stub methods with Photos framework calls.

```swift
import Foundation
import Photos

final class ImageDataSource: ImageDataSourceProtocol {
    func fetchAllIdentifiers() async throws -> [String] {
        // PHPhotoLibrary authorization check
        // PHAsset.fetchAssets to get all image assets
        // Return array of localIdentifier
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        // PHAsset.fetchAssets(withLocalIdentifiers:)
        // PHImageManager.requestImageDataAndOrientation
        // Convert to ImageDTO
    }
}
```
