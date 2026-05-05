---
type: decision
context: error propagation across the UseCase / Domain boundary
keywords: [error, DomainError, UseCaseError, layer-boundary, presentation, domain, usecase]
---

## What

`DomainError` lives in `Domain/Services/` and is thrown internally by Domain Services. UseCases must not propagate `DomainError` to callers — doing so leaks a concrete Domain type through the UseCase boundary into Presentation. Instead, `UseCaseError` (in `UseCases/Requests/`) mirrors the relevant cases and is the only error type Presentation ever sees.

## Do

- Catch `DomainError` inside the UseCase and re-throw as `UseCaseError`
- Mirror only the cases that Presentation actually needs to handle

## Don't

- `throw` a `DomainError` from a UseCase's public method
- Import or reference `DomainError` in Presentation or ViewModels
