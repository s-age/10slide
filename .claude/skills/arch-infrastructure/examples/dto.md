# Example: DTO Types

Raw transport structs that carry data from Infrastructure adapters to Repositories. DTOs contain no logic — they are pure data bags.

## Patterns

### Image DTO — carries binary data with metadata

```swift
// Sources/Infrastructure/Image/DTO/ImageDTO.swift
import Foundation

struct ImageDTO: Sendable {
    let localIdentifier: String
    let data: Data
    let creationDate: Date?
}
```

### Config DTO — serializable for file persistence

```swift
// Sources/Infrastructure/Config/DTO/ConfigDTO.swift
import Foundation

struct ConfigDTO: Sendable, Codable {
    var duration: String
    var transition: String
    var loop: Bool
}
```

## Key points

- Always `Sendable` — DTOs cross actor boundaries
- Add `Codable` only when the DTO is serialized/deserialized (YAML, JSON, plist)
- `import Foundation` only — never framework imports
- Use primitive types (`String`, `Data`, `Date`, `Bool`, `Int`, `Double`) — never domain enums or entities
- Live in `{{Subdirectory}}/DTO/` next to the adapter that produces them
- DTO → Entity conversion belongs in Repositories, not here
