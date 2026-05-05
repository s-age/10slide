---
type: decision
context: deciding whether to add behavioral methods to Domain entities
keywords: [entity, domain, pure-data, behavior, domain-service, slideshow, method-removal]
---

## What

`Slideshow.nextSlideIndex(from:)` and `Slideshow.previousSlideIndex(from:)` were removed after their logic moved to `PlaybackDomainService`. Entities are pure data containers. Behavioral methods that operate only on parameters (not on the entity's own state) belong in Domain Services, not on the entity itself.

## Do

- Keep entities as pure value types with only stored properties and computed properties derived from those properties
- Place navigation, scheduling, or transformation logic in the appropriate Domain Service

## Don't

- Add methods to an entity when the method's logic doesn't depend on `self`'s stored state
- Let entities accumulate behavior over time — prefer moving behavior to Domain Services proactively
