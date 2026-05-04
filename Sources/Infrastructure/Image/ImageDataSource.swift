import Foundation
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
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                if let image, let data = image.tiffRepresentation {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: ImageDataSourceError.dataUnavailable)
                }
            }
        }
    }
}
