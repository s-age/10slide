---
type: discovery
context: when performing file I/O or CPU-heavy work (image decode, YAML parse) inside an async function
keywords: [Swift6, Task.detached, DispatchQueue, concurrency, non-blocking, I/O, QoS, priority]
---

## What

Synchronous work (file I/O, image decoding, YAML parsing) blocks the calling thread when invoked
inside an async function. In Swift 6 the preferred approach is `Task.detached` — the closure is
`@Sendable`, captures must be Sendable, and `.value` propagates thrown errors cleanly.
`DispatchQueue.global + withCheckedThrowingContinuation` works but requires explicit `resume` in
every code path (easy to miss).

See `Sources/Infrastructure/Config/ConfigStore.swift` and
`Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift`.

## Do

Use `Task.detached` for new code:

```swift
func load() async throws -> ConfigDTO {
    let fileURL = self.fileURL   // capture Sendable value locally
    return try await Task.detached(priority: .utility) {
        let data = try Data(contentsOf: fileURL)
        return try YAMLDecoder().decode(ConfigDTO.self, from: data)
    }.value
}
```

QoS / priority mapping:

| Work type           | `Task.detached` priority |
|---------------------|--------------------------|
| Background file I/O | `.utility`               |
| User-initiated      | `.userInitiated`         |
| Thumbnails/prefetch | `.background`            |

## Don't

- Don't call `Data(contentsOf:)` or `NSImage(data:)` directly on a `@MainActor` method.
- Don't capture `self` into a `Task.detached` closure if `self` is not `Sendable`; copy needed
  values into local `let` constants first.
- Don't use `DispatchQueue` continuation for new code — `Task.detached` is simpler and safer.
