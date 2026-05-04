# Photos Framework: Bounding PHAsset Enumeration with fetchLimit

## Problem

`PHAsset.fetchAssets()` can return thousands of photos. Enumerating all of them in a single operation risks memory pressure, UI lag, and performance degradation.

## Pattern

Use `PHFetchOptions.fetchLimit` to cap the result set:

```swift
let fetchOptions = PHFetchOptions()
fetchOptions.fetchLimit = 500   // hard limit on asset count
let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
```

## Why It Matters

On typical macOS systems with large photo libraries, enumerating 10k+ assets can consume significant memory and CPU. A conservative limit (500–1000) balances completeness with performance.

## Trade-offs

- **With limit**: Fast, predictable memory usage, but misses photos beyond the limit
- **Without limit**: Complete enumeration, but can stall the UI or exhaust resources on large libraries

For slideshow creation, a limit is acceptable; users can curate subsets or use smart albums if they need specific photos.

## References

- `Sources/Infrastructure/Image/ImageDataSource.swift` (fetchAllIdentifiers() method, line 17)
- Photos framework: `PHFetchOptions.fetchLimit` documentation
