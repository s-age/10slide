# Example: Data Format Conversion in Infrastructure

Infrastructure may perform low-level data format conversion when the operation requires Infra-only frameworks. This is distinct from DTO→Entity conversion (which belongs in Repositories).

## Guard — all three conditions must be met

| # | Condition | Check |
|---|-----------|-------|
| 1 | Infra-only framework | Uses `ImageIO`, `CoreGraphics`, `AVFoundation`, etc. |
| 2 | Generic output | Returns `Data` or a DTO — never a domain entity |
| 3 | No business logic | No domain rules, no conditional branching on domain state |

## Valid: Thumbnail generation (ImageIO)

```swift
// Sources/Infrastructure/Image/ImageDataSource.swift
func fetchThumbnail(localIdentifier: String) async throws -> Data {
    // ... fetch raw data via Photos ...
    let rawData: Data = try await withCheckedThrowingContinuation { ... }
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
```

**Why this is valid:**
1. Uses `ImageIO` / `CoreGraphics` — only importable in Infrastructure
2. Returns `Data` — generic transport type
3. Pure pixel operation — no domain rules

## Valid: Filesystem thumbnail (CGImageSourceCreateWithURL)

```swift
// Sources/Infrastructure/Image/FileSystemImageDataSource.swift
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
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary)
        else { throw FileSystemImageDataSourceError.unreadable }

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData, "public.jpeg" as CFString, 1, nil
        ) else { throw FileSystemImageDataSourceError.unreadable }

        CGImageDestinationAddImage(
            destination, thumbnail,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw FileSystemImageDataSourceError.unreadable
        }
        return outputData as Data
    }.value
}
```

## Invalid: conversion that leaks business logic

```swift
// Bad — domain-level decisions do not belong here
func fetchThumbnail(localIdentifier: String) async throws -> Data {
    let slide = try await fetchSlide(...)   // NG: domain entity in Infrastructure
    if slide.isHidden { return Data() }     // NG: business logic
    // ...
}
```

## Invalid: conversion that returns a domain entity

```swift
// Bad — returning domain types is Repository's job
func fetchThumbnail(localIdentifier: String) async throws -> Slide {
    // NG: returns Slide (domain entity), not Data
}
```
