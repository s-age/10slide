# Example: Async UseCase with primitive / Void return

A thin pass-through use case that delegates to a Domain Service and returns a primitive type or `Void`. No Response mapping needed.

## Primitive return — `[String]`

### Request — `Sources/UseCases/Requests/FetchLibraryRequest.swift`

```swift
struct FetchLibraryRequest: UseCaseRequest {
    func validate() throws {}
}
```

### Protocol — `Sources/UseCases/Protocols/FetchLibraryUseCaseProtocol.swift`

```swift
typealias FetchLibraryUseCaseProtocol = any AsyncUseCase<FetchLibraryRequest, [String]>
```

### UseCase — `Sources/UseCases/FetchLibraryUseCase.swift`

```swift
import Foundation

final class FetchLibraryUseCase: AsyncUseCase, Sendable {
    private let domainService: any ImageDomainServiceProtocol

    init(domainService: any ImageDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: FetchLibraryRequest) async throws -> [String] {
        return try await domainService.fetchAllIdentifiers()
    }
}
```

### DI wiring

```swift
let fetchLibrary: FetchLibraryUseCaseProtocol

fetchLibrary = ValidationAsyncUseCaseDecorator(
    decoratee: FetchLibraryUseCase(domainService: domain.imageService)
)
```

---

## Void return — fire-and-forget

### Request — `Sources/UseCases/Requests/DeleteSlideshowRequest.swift`

```swift
import Foundation

struct DeleteSlideshowRequest: UseCaseRequest {
    let id: UUID

    func validate() throws {}
}
```

### Protocol — `Sources/UseCases/Protocols/DeleteSlideshowUseCaseProtocol.swift`

```swift
typealias DeleteSlideshowUseCaseProtocol = any AsyncUseCase<DeleteSlideshowRequest, Void>
```

### UseCase — `Sources/UseCases/DeleteSlideshowUseCase.swift`

```swift
import Foundation

final class DeleteSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: DeleteSlideshowRequest) async throws {
        try await domainService.delete(id: request.id)
    }
}
```

### DI wiring

```swift
let deleteSlideshow: DeleteSlideshowUseCaseProtocol

deleteSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: DeleteSlideshowUseCase(domainService: domain.slideshowService)
)
```

## Key points

- Parameterless requests still conform to `UseCaseRequest` with an empty `validate()` body
- Void-returning use cases omit the return type in `execute` signature (`async throws` without `-> Type`)
- Protocol typealias uses `Void` explicitly: `any AsyncUseCase<Request, Void>`
- Thin pass-through is not a smell — it maintains the uniform API surface for Presentation
