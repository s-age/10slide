---
type: gotcha
context: Wrapping PHImageManager.requestImage in a Swift Concurrency continuation
keywords: [PHImageManager, continuation, opportunistic, deliveryMode, crash, double-resume, hang, Photos]
---

## What

`PHImageRequestOptions.deliveryMode = .opportunistic` causes `PHImageManager` to invoke its result callback **twice** — once with a degraded preview and once with the full-quality image. Wrapping this in `withCheckedThrowingContinuation` causes a double-`resume`, which the Swift runtime detects and crashes the app.

Conversely, guarding with `if isDegraded { return }` to skip the first callback means `resume` is never called when the high-quality fetch fails, permanently hanging the task and leaking memory.

## Do

Always use `deliveryMode = .highQualityFormat` when bridging Photos to Swift Concurrency. It guarantees exactly one callback invocation.

```swift
options.deliveryMode = .highQualityFormat  // single callback guaranteed
let data: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
        if let data { continuation.resume(returning: data) }
        else { continuation.resume(throwing: ImageDataSourceError.dataUnavailable) }
    }
}
```

Use `AsyncStream` when progressive/multi-delivery is genuinely required.

## Don't

- Don't use `.opportunistic` with `withCheckedContinuation` or `withCheckedThrowingContinuation`.
- Don't skip degraded callbacks with a guard while leaving the continuation open — it hangs indefinitely.
