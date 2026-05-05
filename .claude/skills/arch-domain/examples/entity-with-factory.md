# Example: Entity with Factory and Update Methods

An entity struct with unique identity, a factory method for construction, and immutable update methods.

## Files to create

### 1. Entity — `Sources/Domain/Entities/Slideshow.swift`

```swift
import Foundation

struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig
    var createdAt: Date

    static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
        Slideshow(
            id: UUID(),
            name: name,
            slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
            config: config,
            createdAt: Date()
        )
    }

    func applying(config: SlideshowConfig) -> Slideshow {
        var updated = self
        updated.config = config
        return updated
    }

    func updating(name: String, localIdentifiers: [String]) -> Slideshow {
        var updated = self
        updated.name = name
        updated.slides = Slideshow.makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0)
        return updated
    }

    private static func makeSlides(from localIdentifiers: [String], duration: TimeInterval) -> [Slide] {
        localIdentifiers.enumerated().map { index, id in
            Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
        }
    }
}
```

## Key points

- `let id: UUID` — immutable identity, assigned at creation
- `static func create(...)` — encapsulates construction rules (ID generation, child creation, timestamps)
- `func applying(...)` / `func updating(...)` — return new copies, never mutate self
- Private helper `makeSlides` is `private static func` — no instance state needed
- References other Domain Entities (`Slide`, `SlideshowConfig`) directly — same layer
- No `import` beyond Foundation
