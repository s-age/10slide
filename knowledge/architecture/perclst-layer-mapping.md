---
type: decision
context: when mapping perclst Clean Architecture concepts to the 10slide Swift codebase
keywords: [architecture, perclst, layer-mapping, DI, validators, SwiftData, DTO, module-name]
---

## What

10slide's Clean Architecture is derived from the perclst TypeScript CLI project. Layer names are
translated to Swift idioms:

| perclst           | Swift                                               |
|-------------------|-----------------------------------------------------|
| `cli`             | `Presentation` (Views + ViewModels + Validators)    |
| `validators`      | `Presentation/Validators`                           |
| `services`        | `UseCases`                                          |
| `domains`         | `Domain/Entities`                                   |
| `repositories`    | `Repositories`                                      |
| `infrastructures` | `Infrastructure`                                    |
| `types`           | `Models`                                            |
| `core/di`         | `DI`                                                |

Non-obvious decisions:

- **Validators live under `Presentation/`** — input validation is a UI concern (field-level errors,
  formatting feedback); UseCases must have no UI knowledge.
- **Infrastructure split by source** — `Infrastructure/Image/` (Photos) and
  `Infrastructure/SwiftData/`, each with its own `DTO/` subdirectory.
- **DI split per layer** — `InfrastructureContainer`, `RepositoryContainer`, `UseCaseContainer`,
  `PresentationContainer` composed by root `Container`; each layer is independently testable.
- **Module name `TenSlide` ≠ target name `10slide`** — Swift module names cannot start with a
  digit; `PRODUCT_MODULE_NAME` is set explicitly in `project.yml`.
- **`@Model` classes live in `Infrastructure/SwiftData/DTO/`** — they are infrastructure DTOs,
  not domain entities; the Repository layer converts them to domain structs.

## Do

- Keep validators in `Presentation/Validators/` — they surface UI feedback, not business rules.
- Place all `@Model` classes in `Infrastructure/SwiftData/DTO/`; never expose them to Domain or
  UseCases.
- Create `ModelContainer` in `InfrastructureContainer` and inject it into SwiftUI via
  `.modelContainer()` in `TenSlideApp`.
- Use one DI container per layer, composed top-to-bottom by the root `Container`.

## Don't

- Don't put validators in `UseCases/` — UseCases must be UI-agnostic.
- Don't reference `@Model` types in `Domain/` or `UseCases/`; use domain entity structs instead.
- Don't use a single monolithic DI container — one container per layer preserves testability.
