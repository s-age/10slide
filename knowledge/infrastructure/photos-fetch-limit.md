---
type: external
context: when fetching PHAsset results from a large photo library
keywords: [Photos, PHAsset, PHFetchOptions, fetchLimit, memory, performance]
---

## What

`PHAsset.fetchAssets()` can return thousands of photos. On macOS systems with large libraries,
enumerating 10k+ assets in a single pass causes memory pressure and UI lag. `PHFetchOptions.fetchLimit`
caps the result set to a safe upper bound.

See `Sources/Infrastructure/Image/ImageDataSource.swift` (`fetchAllIdentifiers()`, line 17).

## Do

Set `fetchLimit` before calling `fetchAssets`:

```swift
let fetchOptions = PHFetchOptions()
fetchOptions.fetchLimit = 500   // hard cap on asset count
let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
```

Use 500–1000 as the cap for slideshow selection; users can curate subsets or use smart albums
for specific photos if the limit is too restrictive.

## Don't

- Don't enumerate without a limit on user photo libraries — library size is unbounded.
- Don't set `fetchLimit = 0` expecting "no limit" — verify the API contract; omit the property or
  use `Int.max` if truly unlimited enumeration is needed.
