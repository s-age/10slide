# Non-Blocking CPU/IO Work in Async Contexts

## Problem

Synchronous work (file I/O, image decoding, etc.) blocks the current thread when called inside an async function. In Swift 6, this should be offloaded explicitly.

## Swift 6 Preferred: `Task.detached`

```swift
func load() async throws -> ConfigDTO {
    let fileURL = self.fileURL
    return try await Task.detached(priority: .utility) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ConfigDTO(duration: "5", transition: "fade", loop: true)
        }
        let data = try Data(contentsOf: fileURL)
        let yaml = String(decoding: data, as: UTF8.self)
        return try YAMLDecoder().decode(ConfigDTO.self, from: yaml)
    }.value
}
```

- Closure is `@Sendable` — captures must be Sendable (use `let` local copies for captured mutable state)
- `.value` suspends until complete and propagates any thrown error
- No manual continuation management needed

## Legacy Pattern: `DispatchQueue.global + withCheckedThrowingContinuation`

Still works in Swift 6 but requires explicit `resume(returning:)` / `resume(throwing:)` in every code path — easy to miss and harder to audit. Prefer `Task.detached` for new code.

```swift
return try await withCheckedThrowingContinuation { continuation in
    DispatchQueue.global(qos: .utility).async {
        do {
            continuation.resume(returning: try expensiveWork())
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
```

## QoS / Priority Mapping

| Work type | `Task.detached` priority | `DispatchQueue.global` qos |
|-----------|--------------------------|---------------------------|
| Background file I/O | `.utility` | `.utility` |
| User-initiated decode | `.userInitiated` | `.userInitiated` |
| Thumbnails/prefetch | `.background` | `.background` |

## References

- `Sources/Infrastructure/Config/ConfigStore.swift` (load/save use `Task.detached`)
- `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` (image decode via `Task.detached`)
