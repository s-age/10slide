# 10slide architecture: perclst → Swift mapping and layer rationale

## Background

10slide adopts Clean Architecture, modeled after the perclst project (a CLI in TypeScript at `../perclst`). The layer names and responsibilities are translated to Swift idioms.

## Layer mapping (perclst → Swift)

| perclst         | Swift                                                       |
|-----------------|-------------------------------------------------------------|
| `cli`           | `Presentation` (Views + ViewModels + Validators)            |
| `validators`    | `Presentation/Validators` (UI concerns stay in Presentation)|
| `services`      | `UseCases`                                                  |
| `domains`       | `Domain/Entities`                                           |
| `repositories`  | `Repositories`                                              |
| `infrastructures` | `Infrastructure`                                          |
| `types`         | `Models`                                                    |
| `core/di`       | `DI`                                                        |

## Non-obvious decisions

- **Validators live under `Presentation/`**, not `UseCases/`. UseCases must have no UI knowledge — input validation is a UI concern (formatting feedback, field-level errors), so it stays adjacent to the views that surface it.
- **Infrastructure is split by source**: `Infrastructure/Image/` (Photos framework) and `Infrastructure/SwiftData/`, each with its own `DTO/` subdirectory. This keeps platform-specific I/O encapsulated.
- **DI is split per layer**, not a single container: `InfrastructureContainer`, `RepositoryContainer`, `UseCaseContainer`, `PresentationContainer` are composed top-to-bottom by the root `Container`. This makes each layer's wiring testable in isolation.
- **Module name (`TenSlide`) differs from target name (`10slide`)** because Swift module names cannot start with a digit. `PRODUCT_MODULE_NAME` in `project.yml` is set explicitly.

## SwiftData specifics

- `@Model` classes (`SlideModel`, `SlideshowModel`) live in `Infrastructure/SwiftData/DTO/`. They are infrastructure DTOs, not domain entities.
- `ModelContainer` is created in `InfrastructureContainer`, passed to the SwiftUI environment via `.modelContainer()` in `TenSlideApp`.
- Data sources create a fresh `ModelContext(container)` per operation rather than holding a shared context — see `knowledge/draft/swiftdata-modelcontext-region-isolation.md` for the region-isolation reasoning.
- The repository layer handles `SlideModel` ↔ `Slide` (entity) conversion so domain code never sees `@Model` classes.

## What CLAUDE.md already covers

CLAUDE.md has the basic layer table and dependency arrow. This file is for the **rationale** and the **perclst lineage** that newcomers need to understand *why* the layers are arranged this way.
