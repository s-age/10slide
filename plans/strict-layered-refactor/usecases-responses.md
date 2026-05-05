# UseCases/Responses Layer

New directory: `Sources/UseCases/Responses/`

These types are the **only** domain-concept types that Presentation may use. They mirror Domain/Entities but belong to the UseCase layer boundary.

---

## `Sources/UseCases/Responses/SlideshowResponse.swift` (new)

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

## `Sources/UseCases/Responses/SlideResponse.swift` (new)

```swift
import Foundation

struct SlideResponse: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
    let duration: TimeInterval
    let title: String?
}
```

## `Sources/UseCases/Responses/SlideshowConfigResponse.swift` (new)

```swift
struct SlideshowConfigResponse: Equatable, Sendable {
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool

    static let `default` = SlideshowConfigResponse(
        duration: .five,
        transition: .fade,
        loop: true
    )
}
```

## `Sources/UseCases/Responses/SlideDurationResponse.swift` (new)

```swift
import Foundation

enum SlideDurationResponse: String, Equatable, Sendable, CaseIterable {
    case five = "5"
    case ten = "10"
    case fifteen = "15"
    case thirty = "30"
    case sixty = "60"
    case manual

    var seconds: TimeInterval? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .thirty: return 30
        case .sixty: return 60
        case .manual: return nil
        }
    }
}
```

## `Sources/UseCases/Responses/TransitionTypeResponse.swift` (new)

```swift
enum TransitionTypeResponse: String, Equatable, Sendable, CaseIterable {
    case none
    case fade
    case slide
    case dissolve

    static let `default` = TransitionTypeResponse.fade
}
```

---

## Mapping Extensions (internal to UseCases layer)

### `Sources/UseCases/Responses/ResponseMapping.swift` (new)

```swift
import Foundation

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

extension SlideResponse {
    init(from entity: Slide) {
        self.init(
            id: entity.id,
            localIdentifier: entity.localIdentifier,
            order: entity.order,
            duration: entity.duration,
            title: entity.title
        )
    }
}

extension SlideshowConfigResponse {
    init(from entity: SlideshowConfig) {
        self.init(
            duration: SlideDurationResponse(from: entity.duration),
            transition: TransitionTypeResponse(from: entity.transition),
            loop: entity.loop
        )
    }
}

extension SlideDurationResponse {
    init(from entity: SlideDuration) {
        self = switch entity {
        case .five: .five
        case .ten: .ten
        case .fifteen: .fifteen
        case .thirty: .thirty
        case .sixty: .sixty
        case .manual: .manual
        }
    }

    var toDomain: SlideDuration {
        switch self {
        case .five: .five
        case .ten: .ten
        case .fifteen: .fifteen
        case .thirty: .thirty
        case .sixty: .sixty
        case .manual: .manual
        }
    }
}

extension TransitionTypeResponse {
    init(from entity: TransitionType) {
        self = switch entity {
        case .none: .none
        case .fade: .fade
        case .slide: .slide
        case .dissolve: .dissolve
        }
    }

    var toDomain: TransitionType {
        switch self {
        case .none: .none
        case .fade: .fade
        case .slide: .slide
        case .dissolve: .dissolve
        }
    }
}

extension SlideshowConfigResponse {
    var toDomain: SlideshowConfig {
        SlideshowConfig(
            duration: duration.toDomain,
            transition: transition.toDomain,
            loop: loop
        )
    }
}
```

---

## Design Notes

- Response types are **read-only** (all `let` properties) — mutations happen via new Requests
- `toDomain` computed properties on Response enums are internal to the UseCase layer (used in Request → Domain conversion). Presentation never calls them.
- `Identifiable` on `SlideshowResponse` and `SlideResponse` enables direct use in SwiftUI `ForEach`/`List`
- `CaseIterable` on enum responses enables SwiftUI `Picker` iteration in Presentation
