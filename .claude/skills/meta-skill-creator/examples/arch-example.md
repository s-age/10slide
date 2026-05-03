---
name: arch-data-flow
description: SwiftData persistence conventions. Use when adding or reviewing data source adapters, DTO definitions, or ModelContainer setup.
paths:
  - 'Sources/Infrastructure/SwiftData/**'
disable-model-invocation: false
---

When adding or reviewing a SwiftData data source:

1. **DTO placement**: `@Model` classes live in `Infrastructure/SwiftData/DTO/` — never in Domain or Repositories
2. **Protocol first**: Define `*DataSourceProtocol` in `Infrastructure/Protocols/` before implementing
3. **Adapter pattern**: Each data source is a `final class` injected with `ModelContainer`
4. **Conversion boundary**: DTOs never cross into Repositories — convert in the repository layer

## ModelContainer setup

- `InfrastructureContainer` creates `ModelContainer` once in `init()`
- Tests use `ModelConfiguration(isStoredInMemoryOnly: true)`
- Never create `ModelContext` at the call site — use `@ModelActor` or inject the container

## Notes

- Never import `SwiftData` outside of `Infrastructure/` (except `App/TenSlideApp.swift` for environment)
- Read `.claude/rules/arch-infrastructure.md` before adding new data sources
