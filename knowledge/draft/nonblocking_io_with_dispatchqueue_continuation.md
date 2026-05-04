# Non-Blocking I/O with DispatchQueue and withCheckedThrowingContinuation

## Problem

Synchronous file I/O (e.g., `Data(contentsOf:)`, `write(to:)`) blocks the async function's thread. In an async context, this defeats the purpose of async/await.

## Pattern

Dispatch I/O to a background QoS queue and bridge back with `withCheckedThrowingContinuation`:

```swift
func load() async throws -> ConfigDTO {
    let fileURL = self.fileURL
    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continuation.resume(returning: ConfigDTO.default)
                return
            }
            do {
                let data = try Data(contentsOf: fileURL)
                let yaml = String(decoding: data, as: UTF8.self)
                let dto = try YAMLDecoder().decode(ConfigDTO.self, from: yaml)
                continuation.resume(returning: dto)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

- **QoS level**: `.utility` (background, non-critical work)
- **Thread safety**: Closure captures `self` and immutable local copies of mutable references (e.g., `fileURL`)
- **Error handling**: Both completion cases (`resume(returning:)` and `resume(throwing:)`) must be covered in all code paths

## Why It Matters

Without this pattern, async file operations remain blocking and don't yield the thread to other tasks, wasting concurrency opportunities.

## References

- `Sources/Infrastructure/Config/ConfigStore.swift` (load() and save() methods)
