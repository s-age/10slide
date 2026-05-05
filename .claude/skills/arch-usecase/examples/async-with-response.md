# Example: Async UseCase with Response mapping

A use case that accepts a Request, delegates to a Domain Service, and maps the returned Domain Entity to a Response type.

## Files to create

### 1. Request — `Sources/UseCases/Requests/CreateSlideshowRequest.swift`

```swift
import Foundation

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let localIdentifiers: [String]
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
```

### 2. Response — `Sources/UseCases/Responses/SlideshowResponse.swift`

```swift
import Foundation

struct SlideshowResponse: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let slides: [SlideResponse]
    let config: SlideshowConfigResponse
    let createdAt: Date
}
```

### 3. Response Mapping — add to `Sources/UseCases/Responses/ResponseMapping.swift`

```swift
extension SlideshowResponse {
    init(from entity: Slideshow) {
        self.init(
            id: entity.id,
            name: entity.name,
            slides: entity.slides.map { SlideResponse(from: $0) },
            config: SlideshowConfigResponse(from: entity.config),
            createdAt: entity.createdAt
        )
    }
}
```

### 4. Protocol — `Sources/UseCases/Protocols/CreateSlideshowUseCaseProtocol.swift`

```swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>
```

### 5. UseCase — `Sources/UseCases/CreateSlideshowUseCase.swift`

```swift
import Foundation

final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        let config = SlideshowConfig(
            duration: request.duration.toDomain,
            transition: request.transition.toDomain,
            loop: request.loop
        )
        let slideshow = try await domainService.create(
            name: request.name,
            localIdentifiers: request.localIdentifiers,
            config: config
        )
        return SlideshowResponse(from: slideshow)
    }
}
```

### 6. DI wiring — add to `Sources/DI/UseCaseContainer.swift`

```swift
// Property declaration
let createSlideshow: CreateSlideshowUseCaseProtocol

// In init(domain:)
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)
```

## Key points

- Request enum fields (`SlideDurationResponse`, `TransitionTypeResponse`) are converted to Domain types via `.toDomain`
- Domain entities are converted to Response types via `Response(from:)` initializers
- No `request.validate()` call — the `ValidationAsyncUseCaseDecorator` handles it in DI
- The use case contains no business logic — it delegates entirely to the Domain Service
