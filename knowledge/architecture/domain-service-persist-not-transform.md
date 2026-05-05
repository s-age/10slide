---
type: problem
context: Domain service methods that return a modified entity without calling repository.save()
keywords: [domain service, persistence, repository, save, applyConfig, in-memory, silent failure, UseCase]
---

## What

`UpdateSlideshowConfigUseCase` delegated to `PlaybackDomainService.applyConfig`, a pure function returning a new `Slideshow` with the updated config. The ViewModel received and displayed the updated object correctly during the session. On next launch the config had reverted — `applyConfig` never called `repository.save()`.

Root cause: the use case split responsibility across two domain services (fetch/transform in one, save missing entirely), violating single-responsibility and making it trivial to omit the persistence step.

## Do

Delegate mutation of persistent state to a single domain service method that owns the full lifecycle — fetch → apply → save → return. For example, `SlideshowDomainService.updateConfig` performs all four steps atomically.

Audit any `applyX` / `withX` / `applying(…)` method in a domain service — if it returns a value without calling `repository.save()`, the caller is responsible for persistence and that responsibility is easy to overlook.

## Don't

- Let a UseCase call two separate domain services to perform what should be one transaction (fetch in one, save in another)
- Assume a method that returns a modified entity has also persisted it
- Name a mutating, persisting method `applyX` — that name convention signals a pure transform
