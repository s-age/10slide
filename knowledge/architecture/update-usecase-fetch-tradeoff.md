---
type: decision
context: UpdateSlideshowConfigUseCase needing the current slideshow before applying a config change
keywords: [usecase, repository, fetch, round-trip, performance, trade-off, config]
---

## What

`UpdateSlideshowConfigUseCase` fetches the slideshow from the repository before applying the config change. This adds a DB round-trip for what was previously a pure in-memory transformation. The trade-off was accepted to maintain architectural consistency (UseCases must not hold stale in-memory state).

## Do

- Accept the extra fetch as the architecturally correct approach
- If performance becomes a bottleneck, carry the full slideshow state in the Request to skip the fetch

## Don't

- Short-circuit the fetch by caching the slideshow in the UseCase — that breaks the stateless UseCase contract
- Let performance concerns drive premature optimization before profiling confirms the round-trip is the bottleneck
