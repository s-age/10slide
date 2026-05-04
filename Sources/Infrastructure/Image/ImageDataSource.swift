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
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw ImageDataSourceError.assetNotFound
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let rawData: Data = try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ImageDataSourceError.dataUnavailable)
                }
            }
        }
        return try await Task.detached(priority: .userInitiated) {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithData(rawData as CFData, sourceOptions as CFDictionary) else {
                throw ImageDataSourceError.dataUnavailable
            }
            let thumbnailOptions: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: 200,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
                throw ImageDataSourceError.dataUnavailable
            }
            let destData = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(destData, "public.jpeg" as CFString, 1, nil) else {
                throw ImageDataSourceError.dataUnavailable
            }
            let destOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
            CGImageDestinationAddImage(dest, cgImage, destOptions as CFDictionary)
            guard CGImageDestinationFinalize(dest) else {
                throw ImageDataSourceError.dataUnavailable
            }
            return destData as Data
        }.value
    }
}
