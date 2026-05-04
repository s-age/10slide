# Infrastructure Layer

## `Sources/Infrastructure/Image/FileSystemImageDataSource.swift` (new)

ディレクトリ内の画像ファイルを読み込む `ImageDataSourceProtocol` 実装。

```swift
import AppKit
import Foundation

final class FileSystemImageDataSource: ImageDataSourceProtocol {
    private static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "webp", "gif", "tiff"]

    private(set) var currentDirectory: URL

    init(directory: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]) {
        self.currentDirectory = directory
    }

    func setDirectory(_ url: URL) {
        currentDirectory = url
    }

    func fetchAllIdentifiers() async throws -> [String] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: currentDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.path)
            .sorted()
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        let url = URL(fileURLWithPath: localIdentifier)
        let data = try Data(contentsOf: url)
        let attributes = try? FileManager.default.attributesOfItem(atPath: localIdentifier)
        let creationDate = attributes?[.creationDate] as? Date
        return ImageDTO(localIdentifier: localIdentifier, data: data, creationDate: creationDate)
    }

    func fetchThumbnail(localIdentifier: String) async throws -> Data {
        let url = URL(fileURLWithPath: localIdentifier)
        guard let image = NSImage(contentsOf: url) else {
            throw FileSystemImageDataSourceError.unreadable
        }
        let size = CGSize(width: 200, height: 200)
        let thumbnail = image.resized(to: size) // NSImage extension
        guard let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = NSBitmapImageRep(cgImage: cgImage)
                  .representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        else {
            throw FileSystemImageDataSourceError.unreadable
        }
        return data
    }
}

enum FileSystemImageDataSourceError: Error {
    case unreadable
}

private extension NSImage {
    func resized(to targetSize: CGSize) -> NSImage {
        let scale = min(targetSize.width / size.width, targetSize.height / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize))
        result.unlockFocus()
        return result
    }
}
```

### 注意点

- `setDirectory(_:)` は `ImageDataSourceProtocol` にないため、DI コンテナが `FileSystemImageDataSource` として保持し、ViewModel がアクセスする形にする（プロトコル経由ではなく型直接）。
- サンドボックス環境ではデスクトップへのアクセスに `com.apple.security.files.user-selected.read-write` entitlement が必要。`NSOpenPanel` を経由することでユーザー選択ディレクトリへのアクセスが許可される。
