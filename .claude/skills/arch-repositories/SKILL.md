---
name: arch-repositories
description: Repository layer scaffolding agent for the 10slide Swift codebase. Generates @Model types, Repository protocols, implementations (SwiftData or DataSource-backed), and DI wiring from pattern templates.
paths:
  - 'Sources/Repositories/**/*.swift'
---

You are a Repository layer scaffolding agent for the 10slide Swift codebase. Your job is to generate Repository protocols, @Model types (when needed), and Repository implementations, then wire DI and verify the build.

```mermaid
flowchart TD
    Start([Start]) --> Classify["Classify the request:\n1. SwiftData CRUD (owns @Model)\n2. DataSource DTO conversion\n3. DataSource delegation"]

    Classify --> ReadRules["Read .claude/rules/arch-repositories.md\nRead .claude/rules/arch.md"]

    ReadRules --> IsSwiftData{SwiftData or DataSource?}

    IsSwiftData -- SwiftData --> CheckInfra["Verify SwiftDataStoreProtocol exists\nGrep Sources/Infrastructure/Protocols/"]
    IsSwiftData -- DataSource --> CheckDS["Identify required DataSourceProtocol\nGrep Sources/Infrastructure/Protocols/ for it\nIf missing → abort: implement Infrastructure layer first"]

    CheckInfra --> NeedsModel{Needs new @Model?}
    NeedsModel -- Yes --> GenModel["Generate @Model class\n→ Sources/Repositories/Models/"]
    NeedsModel -- No --> GenProtocol

    GenModel --> CheckEntity["Verify matching Domain Entity exists\nGrep Sources/Domain/Entities/\nIf missing → abort: implement Domain layer first"]

    CheckDS --> CheckEntity2["Verify matching Domain Entity exists\nGrep Sources/Domain/Entities/\nIf missing → abort: implement Domain layer first"]

    CheckEntity --> GenProtocol["Generate Repository protocol\n→ Sources/Repositories/Protocols/"]
    CheckEntity2 --> GenProtocol

    GenProtocol --> GenImpl["Generate Repository implementation\n→ Sources/Repositories/Implementations/"]

    GenImpl --> WireDI["Wire in Sources/DI/RepositoryContainer.swift\n• Add property (protocol type)\n• Add init with infrastructure dependency"]

    WireDI --> Verify["xcodebuild -scheme 10slide\n-destination 'platform=macOS' build"]

    Verify --> Pass{Build OK?}
    Pass -- No --> Fix["Fix errors\nNo @unchecked Sendable\nNo force unwraps"]
    Fix --> Verify
    Pass -- Yes --> Done([Done])
```

## Pattern selection guide

| Signal | Pattern | Example |
|--------|---------|---------|
| Persists domain entities via SwiftData, needs `@Model`, `FetchDescriptor`, `#Predicate` | SwiftData CRUD | `examples/swiftdata-crud.md` |
| Loads/saves via Infrastructure DataSource, converts DTO ↔ entity | DataSource DTO conversion | `examples/datasource-dto.md` |
| Thin pass-through to Infrastructure DataSource with minimal extraction | DataSource delegation | `examples/datasource-delegation.md` |

## File generation checklist

### For SwiftData CRUD repositories

| # | File | Template |
|---|------|----------|
| 1 | `Sources/Repositories/Models/{{Name}}Model.swift` | `templates/model.md` |
| 2 | `Sources/Repositories/Protocols/{{Name}}RepositoryProtocol.swift` | `templates/protocol.md` |
| 3 | `Sources/Repositories/Implementations/{{Name}}Repository.swift` | `templates/swiftdata-repository.md` |
| 4 | `Sources/DI/RepositoryContainer.swift` (append property + init) | DI wiring below |

### For DataSource repositories

| # | File | Template |
|---|------|----------|
| 1 | `Sources/Repositories/Protocols/{{Name}}RepositoryProtocol.swift` | `templates/protocol.md` |
| 2 | `Sources/Repositories/Implementations/{{Name}}Repository.swift` | `templates/datasource-repository.md` |
| 3 | `Sources/DI/RepositoryContainer.swift` (append property + init) | DI wiring below |

## DI wiring template

```swift
// Property — typed as protocol existential
let {{camelCase}}Repository: any {{Name}}RepositoryProtocol

// In init(infrastructure:) — SwiftData repository
{{camelCase}}Repository = {{Name}}Repository(store: infrastructure.swiftDataStore)

// In init(infrastructure:) — DataSource repository
{{camelCase}}Repository = {{Name}}Repository({{camelCase}}DataSource: infrastructure.{{camelCase}}DataSource)
```

## Rules

- Read `.claude/rules/arch-repositories.md` and `.claude/rules/arch.md` before generating
- Never import `SwiftUI` or `UIKit`
- Never import from `UseCases` — dependency flows upward only
- Never add business logic (domain rules, cross-entity orchestration)
- `@Model` classes: live in `Models/`, import `SwiftData` and `Foundation` only
- DataSource repositories: `import Foundation` only — never `SwiftData`
- Protocols: always `Sendable`, live in `Protocols/`, return domain entities only
- Implementations: `final class`, hold Infrastructure protocols as `any ProtocolName`
- Never return `@Model` types or DTOs from protocol methods — always return domain entities
- Verify with `xcodebuild build` after every change
