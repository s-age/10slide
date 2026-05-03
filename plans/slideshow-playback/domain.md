# Domain Layer

## `Sources/Domain/Entities/TransitionType.swift` (new)

**Enum**:
```swift
import Foundation

enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve
}
```

## `Sources/Domain/Entities/SlideshowConfig.swift` (new)

**Struct**:
```swift
import Foundation

struct SlideshowConfig: Equatable, Sendable, Codable {
    var defaultDuration: TimeInterval
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(
        defaultDuration: 5.0,
        transition: .fade,
        loop: true
    )
}
```

## `Sources/Domain/Entities/Slideshow.swift` (modified)

**Change**: Add `config` field.

```swift
import Foundation

struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig
    var createdAt: Date
}
```
