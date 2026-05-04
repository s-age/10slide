---
paths:
  - 'Sources/Repositories/**/*.swift'
---

Wraps infrastructure data sources into domain-meaningful operations. Converts DTOs ↔ domain entities. Never exposes raw SwiftData models outside this layer.

## Directory layout

```
Repositories/
├── Implementations/   # Concrete classes conforming to protocols
└── Protocols/         # *RepositoryProtocol contracts consumed by UseCases
```

## Import Rules

| May import | Must NOT import |
|-----------|----------------|
| `Foundation`, `Protocols/` (intra), `Domain/Entities` | `SwiftUI`, `UIKit`, `SwiftData` |
| `Infrastructure/Protocols/` (data source protocols) | `Infrastructure` concrete classes directly |
| | `UseCases` — dependency flows upward only |

> Repositories depend on infrastructure **protocols** (`*DataSourceProtocol`), never on concrete classes.

## Patterns

**DTO → entity conversion** — convert inside the repository; DTOs never leak to callers

```swift
// Good — entity returned, DTO stays internal
func fetchAll() async throws -> [Slide] {
    let models = try await slideDataSource.fetchAll()
    return models.map {
        Slide(id: $0.id, localIdentifier: $0.localIdentifier,
              order: $0.order, duration: $0.duration, title: $0.title)
    }
}

// Bad — leaking SwiftData model to the caller
func fetchAll() async throws -> [SlideModel] { ... }   // NG: DTO must not cross this boundary
```

**Protocol placement** — every repository protocol lives in `Protocols/`, never in the implementation file

```swift
// Good — Protocols/SlideRepositoryProtocol.swift
protocol SlideRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slide]
    func save(_ slide: Slide, in slideshowID: UUID) async throws
    func delete(id: UUID) async throws
}
```

**Dependency injection** — inject data source protocols, not concrete classes

```swift
// Good
final class SlideRepository: SlideRepositoryProtocol {
    private let slideDataSource: any SlideDataSourceProtocol

    init(slideDataSource: any SlideDataSourceProtocol) {
        self.slideDataSource = slideDataSource
    }
}
```

## Prohibitions

- Never import `SwiftData` directly — access persistence through `*DataSourceProtocol`
- Never import `SwiftUI` or `UIKit`
- Never import from `UseCases` — dependency flows upward only
- Never add business logic (domain rules, cross-entity orchestration)
- Never define a protocol in an implementation file — protocols live in `Protocols/`
- Never return DTOs (`*Model`) from protocol methods — always return domain entities
