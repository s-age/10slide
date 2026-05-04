---
paths:
  - 'Sources/**/*.swift'
---

Before writing or reviewing **any** file under `Sources/`, answer all three:

1. **Which layer owns this change?** — `Presentation` / `UseCases` / `Repositories` / `Infrastructure` / `Domain/Entities` / `DI`
2. **What may this layer import?** — check the allowlist in each layer's rule file
3. **Does this introduce a forbidden import?** — SwiftLint custom rules in `.swiftlint.yml` enforce these; verify before writing

Do not write code if you cannot answer all three.

## Import flow

```
Presentation ──→ UseCases ──→ Repositories ──→ Infrastructure
                     ↑               ↑
              Domain/Entities   (protocols only — no concrete classes)
                  (shared)
```

## Hard prohibitions (enforced by SwiftLint)

- `Domain` → `SwiftData`, `Photos`, `SwiftUI`, `UIKit`
- `UseCases` → `SwiftData`, `Photos`, `SwiftUI`, `UIKit`
- `Repositories` → `SwiftUI`, `UIKit`
- Any layer (except `Infrastructure`) → direct framework I/O

## Swift 6 concurrency

Every type passed across actor boundaries must conform to `Sendable`. Protocols should declare `Sendable` when conforming types will cross actors.

```swift
// Good — explicitly Sendable where values cross actors
protocol SlideRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slide]
}

// Bad — omitting Sendable causes Swift 6 compiler errors in async contexts
protocol SlideRepositoryProtocol {
    func fetchAll() async throws -> [Slide]
}
```

## Mutex for cross-actor state

When mutable state must be accessed safely from multiple actors or threads, use `Mutex` (from `Synchronization`) instead of wrapping the type in an actor or adding `@unchecked Sendable`.

```swift
import Synchronization

// Good — Mutex wraps the mutable value; safe to share across actors
final class ImageCache: Sendable {
    private let storage: Mutex<[String: Data]> = Mutex([:])

    func store(_ data: Data, for key: String) {
        storage.withLock { $0[key] = data }
    }

    func retrieve(for key: String) -> Data? {
        storage.withLock { $0[key] }
    }
}

// Bad — @unchecked Sendable hides the race condition
final class ImageCache: @unchecked Sendable {
    private var storage: [String: Data] = [:]   // unsynchronized — data race
}
```

Use `Mutex` when:
- A `final class` needs to be `Sendable` with mutable state
- Shared mutable state must survive across `await` boundaries without being isolated to a single actor

## Struct vs Class

- **Value types (`struct`)**: Domain entities, DTOs, input/output data bags
- **Reference types (`class`)**: Infrastructure adapters, repositories, use cases, DI containers, ViewModels

```swift
// Good — domain entity is a value type
struct Slide: Identifiable, Equatable, Sendable { ... }

// Good — repository is a reference type (holds stateful dependencies)
final class SlideRepository: SlideRepositoryProtocol { ... }
```

## Protocol abstractions

Every concrete implementation that crosses a layer boundary must have a corresponding protocol.

```swift
// Good — protocol in Protocols/
protocol SlideRepositoryProtocol: Sendable { ... }
final class SlideRepository: SlideRepositoryProtocol { ... }

// Bad — DI container holds the concrete type
let repo = SlideRepository(...)   // should be `any SlideRepositoryProtocol`
```

## Xcode project file

`Sources/` is registered as a `PBXFileSystemSynchronizedRootGroup` in the `.xcodeproj`. Any `.swift` file created or deleted under `Sources/` is automatically included in or excluded from the build — no manual edits to `project.pbxproj` are needed.

## Verify after every change

```bash
xcodebuild -scheme 10slide -destination 'platform=macOS' build
```

SwiftLint runs automatically as a build phase. Fix all errors and warnings before completing.
