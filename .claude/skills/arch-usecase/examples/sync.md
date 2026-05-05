# Example: Sync UseCase (pure computation)

A use case that performs synchronous, non-I/O work. Uses `SyncUseCase` instead of `AsyncUseCase`. No `async`/`await`.

## With validation — `AdvanceSlideUseCase`

### Request — `Sources/UseCases/Requests/AdvanceSlideRequest.swift`

```swift
struct AdvanceSlideRequest: UseCaseRequest {
    let totalSlides: Int
    let currentIndex: Int
    let loop: Bool

    func validate() throws {
        guard totalSlides > 0 else { throw ValidationError.noSlides }
        guard currentIndex >= 0, currentIndex < totalSlides else {
            throw ValidationError.invalidIndex
        }
    }
}
```

### Protocol — `Sources/UseCases/Protocols/AdvanceSlideUseCaseProtocol.swift`

```swift
typealias AdvanceSlideUseCaseProtocol = any SyncUseCase<AdvanceSlideRequest, Int?>
```

### UseCase — `Sources/UseCases/AdvanceSlideUseCase.swift`

```swift
final class AdvanceSlideUseCase: SyncUseCase, Sendable {
    private let domainService: any PlaybackDomainServiceProtocol

    init(domainService: any PlaybackDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        domainService.nextIndex(
            totalSlides: request.totalSlides,
            currentIndex: request.currentIndex,
            loop: request.loop
        )
    }
}
```

### DI wiring

```swift
let advanceSlide: AdvanceSlideUseCaseProtocol

advanceSlide = ValidationSyncUseCaseDecorator(
    decoratee: AdvanceSlideUseCase(domainService: domain.playbackService)
)
```

---

## Without validation — `AddDroppedFilesUseCase`

### Request — `Sources/UseCases/Requests/AddDroppedFilesRequest.swift`

```swift
import Foundation

struct AddDroppedFilesRequest: UseCaseRequest {
    let urls: [URL]
    let existingIdentifiers: [String]

    func validate() throws {}
}
```

### Protocol — `Sources/UseCases/Protocols/AddDroppedFilesUseCaseProtocol.swift`

```swift
typealias AddDroppedFilesUseCaseProtocol = any SyncUseCase<AddDroppedFilesRequest, [String]>
```

### UseCase — `Sources/UseCases/AddDroppedFilesUseCase.swift`

```swift
import Foundation

final class AddDroppedFilesUseCase: SyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: AddDroppedFilesRequest) throws -> [String] {
        domainService.filterDroppedFiles(
            urls: request.urls,
            existingIdentifiers: request.existingIdentifiers
        )
    }
}
```

### DI wiring

```swift
let addDroppedFiles: AddDroppedFilesUseCaseProtocol

addDroppedFiles = ValidationSyncUseCaseDecorator(
    decoratee: AddDroppedFilesUseCase(domainService: domain.imageService)
)
```

## Key points

- `SyncUseCase` — no `async`/`await`, `execute` is `throws` only
- `import Foundation` is omitted when no Foundation types are used (primitives only)
- DI uses `ValidationSyncUseCaseDecorator` (not `ValidationAsyncUseCaseDecorator`)
- Sync use cases are for pure computation with no I/O — if the Domain Service needs async, use `AsyncUseCase`
- Implicit return is used when the function body is a single expression
