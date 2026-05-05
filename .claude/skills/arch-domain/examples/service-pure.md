# Example: Domain Service (Pure Computation)

A service with no Repository dependency that encapsulates pure business logic.

## Files to create

### 1. Protocol — `Sources/Domain/Services/Protocols/PlaybackDomainServiceProtocol.swift`

```swift
protocol PlaybackDomainServiceProtocol: Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int?
    func previousIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int?
}
```

### 2. Implementation — `Sources/Domain/Services/PlaybackDomainService.swift`

```swift
import Foundation

final class PlaybackDomainService: PlaybackDomainServiceProtocol, Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex < totalSlides - 1 { return currentIndex + 1 }
        return loop ? 0 : nil
    }

    func previousIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex > 0 { return currentIndex - 1 }
        return loop ? totalSlides - 1 : nil
    }
}
```

### 3. DI wiring — add to `Sources/DI/DomainContainer.swift`

```swift
// Property declaration
let playbackService: any PlaybackDomainServiceProtocol

// In init(repositories:) — no repository needed
playbackService = PlaybackDomainService()
```

## When to use this pattern

- Logic is pure computation — no I/O, no persistence, no side effects
- Logic is complex enough to warrant extraction from an Entity (e.g. navigation algorithms, scoring, validation rules)
- Multiple UseCases or ViewModels would otherwise duplicate the same calculation

## Key points

- No `init` parameters — no dependencies
- No `async`, no `throws` — methods are synchronous and infallible (or return `Optional`)
- No `import Foundation` needed if signatures use only primitives
- Protocol may omit `import Foundation` entirely
- Highly testable — pure input→output with no mocking required
