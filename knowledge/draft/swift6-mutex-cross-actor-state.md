# Mutex for cross-actor mutable state in Swift 6

## Problem

In Swift 6, a `final class` with mutable stored properties cannot conform to `Sendable` without either:
- isolating it to a single actor (`@MainActor`), or
- marking it `@unchecked Sendable` (which silences the compiler but hides the race condition)

The common but dangerous workaround is `@unchecked Sendable`:

```swift
// Bad — data race is hidden, not fixed
final class ImageCache: @unchecked Sendable {
    private var storage: [String: Data] = [:]   // unsynchronized
}
```

## Solution

Use `Mutex` from the `Synchronization` module (introduced in Swift 6 / Xcode 16). It wraps a value and enforces that all access goes through a lock, making the type genuinely `Sendable`.

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

## When to use

- A `final class` needs to be `Sendable` but holds mutable state
- The mutable state must survive across `await` boundaries without being pinned to a single actor
- Multiple actors or threads need read/write access to the same value

## When NOT to use

- If the type is only ever accessed from `@MainActor`, just annotate `@MainActor` — no Mutex needed
- If the value is only written once at init and then read-only, `let` already makes it `Sendable`

## Key detail

`Mutex` is a non-escaping lock — `withLock` cannot itself `await`, so it is appropriate for synchronous critical sections only. For async-safe shared state, consider an `actor` instead.
