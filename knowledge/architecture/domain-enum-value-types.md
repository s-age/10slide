---
type: discovery
context: when designing domain types that represent a closed set of alternatives
keywords: [domain, enum, value-type, Sendable, Codable, TransitionType, arch-domain]
---

## What

The `arch-domain.md` rule originally said "all domain types are `struct`". This is overly
restrictive — the actual constraint is that domain entities must be **value types** (no reference
semantics). Swift `enum` is a value type and is preferred for closed variant sets.

Example: `TransitionType` with cases `none, fade, slide, dissolve` is naturally an `enum`, not a
`struct` with `static let` constants. The rule was updated to permit `enum` for closed variant
sets. Exhaustive `switch` checking at compile time makes enums the correct choice here.

## Do

- Use `enum` for domain types that represent a closed, fixed set of alternatives.
- Conform to `Codable`, `Sendable`, `Equatable`, `CaseIterable` as the use case requires.
- Use a `String` raw value when the enum round-trips through DTOs — avoids breaking serialization
  on case reordering.

## Don't

- Don't use `class` for domain types — reference semantics violate the value-type constraint.
- Don't reach for a `struct` with `static let` constants when an `enum` would give exhaustive
  `switch` checking for free.
- Don't use `enum` for open-ended, extensible concepts — `enum` is for **closed** sets; prefer
  `struct` or a protocol for domain concepts that users or future layers may extend.
