# Example: Framework Adapter (Photos)

An adapter that wraps a system framework (`Photos`) and returns raw DTOs. Includes data format conversion (thumbnail generation) inside `Task.detached`.

## Files to create

### 1. Protocol — `Sources/Infrastructure/Protocols/ImageDataSourceProtocol.swift`

```swift
import Foundation

protocol ImageDataSourceProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImage(localIdentifier: String) async throws -> ImageDTO
    func fetchThumbnail(localIdentifier: String) async throws -> Data
    func setDirectory(_ url: URL)
    var supportedExtensions: Set<String> { get }
}

extension ImageDataSourceProtocol {
    func setDirectory(_ url: URL) {}
    var supportedExtensions: Set<String> { [] }
}
```

### 2. DTO — `Sources/Infrastructure/Image/DTO/ImageDTO.swift`

```swift
import Foundation

struct ImageDTO: Sendable {
    let localIdentifier: String
    let data: Data
    let creationDate: Date?
}
```

### 3. Implementation — `Sources/Infrastructure/Image/ImageDataSource.swift`

```swift
import Foundation
import ImageIO
import Photos

enum ImageDataSourceError: Error {
    case notAuthorized
    case assetNotFound
    case dataUnavailable
}

final class ImageDataSource: ImageDataSourceProtocol {
    func fetchAllIdentifiers() async throws -> [String] {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw ImageDataSourceError.notAuthorized
        }
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 500
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var identifiers: [String] = []
        identifiers.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            identifiers.append(asset.localIdentifier)
        }
        return identifiers
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw ImageDataSourceError.assetNotFound
        }
        let creationDate = asset.creationDate
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                if let data {
                    continuation.resume(returning: ImageDTO(
                        localIdentifier: localIdentifier,
                        data: data,
                        creationDate: creationDate
                    ))
                } else {
                    continuation.resume(throwing: ImageDataSourceError.dataUnavailable)
                }
            }
        }
    }

    func fetchThumbnail(localIdentifier: String) async throws -> Data {
        // ... fetch raw data via Photos (withCheckedThrowingContinuation) ...
        return try await Task.detached(priority: .userInitiated) {
            // CGImageSource → resize → JPEG encode → Data
        }.value
    }
}
```

### 4. DI wiring — add to `Sources/DI/InfrastructureContainer.swift`

```swift
let imageDataSource: any ImageDataSourceProtocol

// In init
imageDataSource = ImageDataSource()
```

## Key points

- `final class`, not `@ModelActor` — Photos does not use `ModelContext`
- Authorization via `requestAuthorization(for: .readWrite)` — not `authorizationStatus`
- `PHAccessLevel` has only `.addOnly` and `.readWrite` — no `.readOnly`
- `deliveryMode = .highQualityFormat` inside continuations — never `.opportunistic`
- `requestImageDataAndOrientation` returns `Data` — avoids `AppKit` dependency
- `fetchThumbnail` performs data format conversion: allowed because it uses `ImageIO` (Infra-only framework), returns `Data` (generic output), and contains no business logic
- `fetchLimit = 500` on `PHFetchOptions` to cap enumeration
- Default implementations on protocol for `setDirectory` and `supportedExtensions` — only `FileSystemImageDataSource` overrides these
