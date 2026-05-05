---
type: decision
context: Where to place error enums that must be visible and displayable across all layers
keywords: [errors, shared, leaf, layer, DomainError, LocalizedError, architecture, Sources/Errors]
---

## What

Per-layer error enums caused dead code (UseCaseError duplicated DomainError cases but was never referenced), layer leakage (DomainError crossing to Presentation without `LocalizedError`, producing broken UI text), and placement confusion (error enums in `Requests/` was semantically wrong).

`Sources/Errors/` was created as a **shared leaf-node layer** — depends only on Foundation, accessible from all layers. It is the sole exception to the strict one-way dependency rule. Errors are inherently cross-cutting: they originate in one layer but must be displayable in another. The "don't leak domain types" principle applies to Entities (which have structure and behavior), not to error enums (which are pure signals).

## Do

- Place all error enums under `Sources/Errors/`
- Keep one enum per failure domain (not a monolithic `AppError`)
- Conform every enum to `LocalizedError`
- Use Foundation-only associated values — never Entity or DTO types
- Name the directory specifically (`Errors/`), not generically (`Shared/`, `Common/`, `Constant/`)

## Don't

- Add business logic or protocols to `Sources/Errors/`
- Use Entity or DTO types as associated values (creates layer coupling)
- Create per-layer error enums and remap at each boundary — boilerplate cost exceeds benefit at current scale
- Use `Sources/Errors/` as a general utilities dumping ground
