# Rules Layer (modified)

Architecture rules and SwiftLint config updated to enforce the new layered structure.

---

## `.claude/rules/arch.md` (modified)

Updated import flow diagram:

```
Presentation ──→ UseCases (Requests/Responses) ──→ Domain/Services ──→ Repositories ──→ Infrastructure
                                                        ↑
                                                  Domain/Entities
                                                    (shared)
```

Key changes:
- Presentation may NOT import `Domain/Entities` — only `UseCases/Requests` and `UseCases/Responses`
- UseCases may import `Domain/Entities` (for mapping) and `Domain/Services/Protocols`
- Domain/Services may import `Repositories/Protocols` and `Domain/Entities`
- Domain/Entities remains Foundation-only (unchanged)

---

## `.claude/rules/arch-domain-services.md` (new)

```markdown
---
paths:
  - 'Sources/Domain/Services/**/*.swift'
---

When creating, editing, or reviewing any file in `Sources/Domain/Services/`:

- **Layer responsibility**: Orchestrates Repository calls and Entity logic. The sole consumer of Repository protocols in the architecture.
- **Import allowlist**: `Foundation`, `Domain/Entities`, `Repositories/Protocols` — never `SwiftData`, `Photos`, `SwiftUI`, `UIKit`, `Infrastructure`, `UseCases`.

## Directory layout

\```
Domain/Services/
├── Protocols/   # *DomainServiceProtocol contracts consumed by UseCases
└── *.swift      # Concrete implementations
\```

## Patterns

**Service — `final class` conforming to protocol + `Sendable`**

\```swift
final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    private let repository: any SlideshowRepositoryProtocol

    init(repository: any SlideshowRepositoryProtocol) {
        self.repository = repository
    }
}
\```

**Entity creation + persistence in one operation**

\```swift
func create(name: String, ...) async throws -> Slideshow {
    let entity = Slideshow.create(name: name, ...)
    try await repository.save(entity)
    return entity
}
\```

## Prohibitions

- Never import `SwiftData`, `Photos`, `SwiftUI`, or `UIKit`
- Never import from `UseCases` — dependency flows upward only
- Never import `Infrastructure` concrete types — use Repository protocols
- Never expose Repository protocols to callers — callers see only DomainServiceProtocol
- Never place protocols in implementation files — protocols live in `Protocols/`
```

---

## `.claude/rules/arch-presentation.md` (modified)

Import allowlist update:
```
- **Import allowlist**: `SwiftUI`, `AppKit`, `Foundation`, `UseCases/Protocols`, `UseCases/Requests`, `UseCases/Responses` — never `Domain`, `Repositories`, `Infrastructure`, `SwiftData`, `Photos`.
```

New prohibition added:
```
- Never import `Domain/Entities` or `Domain/Services` — use Response types from UseCases
```

---

## `.claude/rules/arch-usecases.md` (modified)

Import allowlist update:
```
- **Import allowlist**: `Foundation`, `Domain/Entities`, `Domain/Services/Protocols` — never `Repositories`, `Infrastructure`, `SwiftData`, `Photos`, `SwiftUI`, `UIKit`.
```

New prohibition:
```
- Never import `Repositories/Protocols` directly — route through Domain Services
```

---

## `.swiftlint.yml` (modified)

Add new custom rules:

```yaml
custom_rules:
  presentation_no_domain_import:
    name: "Presentation must not import Domain"
    regex: '(?:Sources/Presentation/).*import\s+(?:Slideshow|Slide[^R]|SlideshowConfig|SlideDuration|TransitionType)(?!\w*Response)'
    message: "Presentation layer must use Response types, not Domain entities"
    severity: error

  usecases_no_repository_import:
    name: "UseCases must not use Repository protocols"
    regex: '(?:Sources/UseCases/).*(?:Repository|RepositoryProtocol)'
    message: "UseCases must use Domain Services, not Repositories directly"
    severity: error

  domain_services_allowed_imports:
    name: "Domain Services import check"
    regex: '(?:Sources/Domain/Services/).*import\s+(?:SwiftData|Photos|SwiftUI|UIKit)'
    message: "Domain Services may only import Foundation"
    severity: error
```

Note: The exact regex patterns may need tuning based on how SwiftLint resolves file paths in this project. The existing `domain_no_framework_import` rule continues to cover `Domain/Entities/`.
