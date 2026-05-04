---
type: decision
context: Adding display-oriented computed properties to Domain-layer enums or structs
keywords: [domain, presentation, extension, displayLabel, UI, arch-domain, formatter, computed-property]
---

## What

Domain-layer types must not contain UI-display computed properties (e.g. `displayLabel`, `displayName`, `formattedValue`). This is an explicit prohibition in `arch-domain.md`: "Never add computed UI formatters." Placing them on the Domain type imports UI concerns into a layer that must remain framework-free.

## Do

Create a `<TypeName>+Presentation.swift` extension file in `Sources/Presentation/Views/` and define display properties there.

```swift
// Sources/Presentation/Views/SlideDuration+Presentation.swift
extension SlideDuration {
    var displayLabel: String {
        switch self {
        case .five:   return "5 sec"
        case .manual: return "None"
        // …
        }
    }
}
```

- File name: `<TypeName>+Presentation.swift`
- Location: `Sources/Presentation/Views/`
- No extra import needed (single-module project)
- Call sites (Views) require no changes

## Don't

- Don't add `displayLabel`, `title`, `description`, or any "display" property to Domain files — flag these immediately in review.
- Don't confuse domain calculations (e.g. `seconds: TimeInterval`) with display formatters — pure domain math belongs in the Domain layer.
