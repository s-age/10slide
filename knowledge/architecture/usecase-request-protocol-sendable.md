---
type: gotcha
context: defining UseCase request types under Swift 6 strict concurrency
keywords: [swift6, sendable, protocol, usecase, request, concurrency, class-inheritance]
---

## What

The original design used a base class (`class UseCaseRequest`) with subclass inheritance to enforce a `validate()` contract. Swift 6 Strict Concurrency makes this unworkable: a non-final class cannot conform to `Sendable`, and `@unchecked Sendable` is banned by project rules.

## Do

- Define `protocol UseCaseRequest: Sendable` and have each request be a `struct` conformer
- Rely on automatic `Sendable` synthesis that structs get for free when all stored properties are `Sendable`

## Don't

- Use a base class for `UseCaseRequest` — it cannot be made safely `Sendable` under Swift 6
- Reach for `@unchecked Sendable` on request types — it is banned by project lint rules
