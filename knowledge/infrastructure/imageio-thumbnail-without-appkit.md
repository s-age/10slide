---
type: discovery
context: Generating image thumbnails in the Infrastructure layer without importing AppKit
keywords: [ImageIO, thumbnail, AppKit, Photos, CGImageSource, Task.detached, HEIF, JPEG, arch]
---

## What

`PHImageManager.requestImage` returns `NSImage` on macOS, creating an AppKit dependency. The Infrastructure layer must not import AppKit (architectural rule). `ImageIO` provides a fully AppKit-free path: fetch raw bytes via `requestImageDataAndOrientation`, then decode and resize with `CGImageSourceCreateThumbnailAtIndex` off the main thread.

`CGImageSourceCreateThumbnailAtIndex` reads only the pixels needed for the requested size — it does not decode the full-resolution image — making it efficient even for large HEIF files.

## Do

```swift
// 1. Fetch raw data from Photos (no AppKit dependency)
let options = PHImageRequestOptions()
options.deliveryMode = .highQualityFormat
let rawData: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
        if let data { continuation.resume(returning: data) }
        else { continuation.resume(throwing: ImageDataSourceError.dataUnavailable) }
    }
}

// 2. Decode + resize on a background thread (CPU-bound)
return try await Task.detached(priority: .userInitiated) {
    guard let source = CGImageSourceCreateWithData(rawData as CFData,
                           [kCGImageSourceShouldCache: false] as CFDictionary)
    else { throw ImageDataSourceError.dataUnavailable }

    let opts: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: 200,
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,  // apply EXIF rotation
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
    else { throw ImageDataSourceError.dataUnavailable }

    let dest = NSMutableData()
    guard let imageDest = CGImageDestinationCreateWithData(dest, "public.jpeg" as CFString, 1, nil)
    else { throw ImageDataSourceError.dataUnavailable }
    CGImageDestinationAddImage(imageDest, cgImage,
                               [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    guard CGImageDestinationFinalize(imageDest) else { throw ImageDataSourceError.dataUnavailable }
    return dest as Data
}.value
```

## Don't

- Don't import `AppKit` in Infrastructure just to get `NSImage` for resizing — use `ImageIO` instead.
- Don't run `CGImageSourceCreateThumbnailAtIndex` on the main thread; it is CPU-bound and will block the UI.
