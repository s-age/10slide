# Example: DataSource Delegation Repository

A thin repository that delegates to an Infrastructure DataSource with minimal DTO extraction.

## Files to create

### 1. Protocol — `Sources/Repositories/Protocols/ImageRepositoryProtocol.swift`

```swift
import Foundation

protocol ImageRepositoryProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImageData(localIdentifier: String) async throws -> Data
    func fetchThumbnailData(localIdentifier: String) async throws -> Data
    func setDirectory(_ url: URL) async
    var supportedExtensions: Set<String> { get }
}
```

### 2. Implementation — `Sources/Repositories/Implementations/ImageRepository.swift`

```swift
import Foundation

final class ImageRepository: ImageRepositoryProtocol {
    private let imageDataSource: any ImageDataSourceProtocol

    init(imageDataSource: any ImageDataSourceProtocol) {
        self.imageDataSource = imageDataSource
    }

    func fetchAllIdentifiers() async throws -> [String] {
        try await imageDataSource.fetchAllIdentifiers()
    }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        let dto = try await imageDataSource.fetchImage(localIdentifier: localIdentifier)
        return dto.data
    }

    func fetchThumbnailData(localIdentifier: String) async throws -> Data {
        try await imageDataSource.fetchThumbnail(localIdentifier: localIdentifier)
    }

    func setDirectory(_ url: URL) async {
        imageDataSource.setDirectory(url)
    }

    var supportedExtensions: Set<String> {
        imageDataSource.supportedExtensions
    }
}
```

### 3. DI wiring — add to `Sources/DI/RepositoryContainer.swift`

```swift
// Property declaration
let imageRepository: any ImageRepositoryProtocol

// In init(infrastructure:)
imageRepository = ImageRepository(imageDataSource: infrastructure.imageDataSource)
```

## Key points

- No `SwiftData` import — only `Foundation`
- Most methods are direct pass-through to DataSource
- DTO extraction only where needed (`dto.data` for image fetch)
- Computed properties delegate synchronously when backing source is non-async
- Async methods without `throws` are valid when the DataSource method doesn't throw
- DataSource protocol held as `any ImageDataSourceProtocol` — never concrete
