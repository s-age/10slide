# Domain layer accepts enum, not just struct

## Discovery

The `arch-domain.md` rule originally read "all domain types are `struct`". That phrasing is overly restrictive — the actual constraint is that domain entities must be **value types** (no reference semantics), and Swift `enum` is a value type.

The rule was updated to permit `enum` for closed variant sets. Example: `TransitionType` with cases `none, fade, slide, dissolve` is naturally an `enum`, not a `struct` with static let constants.

## Why enum is preferred for closed variant sets

- Exhaustive `switch` checking at compile time
- Semantic clarity that the set is closed and fixed
- Less boilerplate than a `struct` with `static let` constants
- Trivially `Codable`, `Sendable`, `Equatable` via raw-value conformance

## How to apply

When designing a domain type that represents a closed set of alternatives (transition types, animation types, status enums, etc.), use `enum`. The prohibition is against `class` (reference semantics), never against `enum`.

Conform to `Codable`, `Sendable`, `Equatable`, `CaseIterable` as the use case requires. Use a `String` raw value when the enum needs to round-trip through DTOs (avoids breaking serialization on case reordering).
