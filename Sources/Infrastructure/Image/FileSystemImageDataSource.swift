import Foundation
import ImageIO
import Synchronization

enum FileSystemImageDataSourceError: Error {
    case unreadable
}

final class FileSystemImageDataSource: ImageDataSourceProtocol {
    internal static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "webp", "gif", "tiff"]

    private let _currentDirectory: Mutex<URL>

    var currentDirectory: URL {
        _currentDirectory.withLock { $0 }
    }

    init(directory: URL = FileManager.default.urls(
        for: .desktopDirectory, in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory) {
        _currentDirectory = Mutex(directory)
    }

    func setDirectory(_ url: URL) {
        _currentDirectory.withLock { $0 = url }
    }

    func fetchAllIdentifiers() async throws -> [String] {
        let directory = currentDirectory
        return try await Task.detached(priority: .userInitiated) {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )
            return contents
                .filter { FileSystemImageDataSource.supportedExtensions.contains($0.pathExtension.lowercased()) }
                .map { $0.path }
                .sorted()
        }.value
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        let (data, creationDate) = try await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: localIdentifier)
            let data = try Data(contentsOf: url)
            let attributes = try? FileManager.default.attributesOfItem(atPath: localIdentifier)
            let creationDate = attributes?[.creationDate] as? Date
            return (data, creationDate)
        }.value
        return ImageDTO(localIdentifier: localIdentifier, data: data, creationDate: creationDate)
    }

    func fetchThumbnail(localIdentifier: String) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: localIdentifier)
            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 200
            ]
            guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                      source, 0, thumbnailOptions as CFDictionary
                  )
            else { throw FileSystemImageDataSourceError.unreadable }

            let outputData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                outputData, "public.jpeg" as CFString, 1, nil
            ) else { throw FileSystemImageDataSourceError.unreadable }

            CGImageDestinationAddImage(
                destination,
                thumbnail,
                [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
            )
            guard CGImageDestinationFinalize(destination) else {
                throw FileSystemImageDataSourceError.unreadable
            }
            return outputData as Data
        }.value
    }
}
