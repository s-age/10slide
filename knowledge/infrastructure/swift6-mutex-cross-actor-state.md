---
type: external
context: when a final class needs mutable state that is safely Sendable in Swift 6
keywords: [Swift6, Mutex, Sendable, concurrency, Synchronization, cross-actor]
---

## What

Swift 6's `Synchronization` module provides `Mutex<T>`, which wraps a value and enforces all
access through a lock, making a `final class` genuinely `Sendable` without `@unchecked Sendable`.
`Mutex.withLock` takes the wrapped value as `inout sending` — it is synchronous-only and cannot
itself `await`.

```swift
import Synchronization

final class ImageCache: Sendable {
    private let storage: Mutex<[String: Data]> = Mutex([:])

    func store(_ data: Data, for key: String) {
        storage.withLock { $0[key] = data }
    }

    func retrieve(for key: String) -> Data? {
        storage.withLock { $0[key] }
    }
}
```

## Do

- Import `Synchronization` and wrap mutable shared state in `Mutex<T>`.
- Access state exclusively via `storage.withLock { ... }`.
- Use `Mutex` when multiple actors or threads need read/write access to the same value across
  `await` boundaries.
- Prefer `actor` instead of `Mutex` when the critical section itself needs to `await`.

## Don't

- Don't use `@unchecked Sendable` — it silences the compiler but hides the data race.
- Don't use `Mutex` when the type is only ever accessed from `@MainActor`; annotate `@MainActor`
  instead.
- Don't use `Mutex` when the value is written once at init and then read-only; `let` already makes
  it `Sendable`.
- Don't call `await` inside `withLock` — it is a compile error and conceptually wrong.
