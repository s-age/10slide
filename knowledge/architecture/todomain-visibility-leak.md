---
type: gotcha
context: response enum helpers that reverse-convert to domain types in a single-target app
keywords: [visibility, internal, response, domain, toDomain, single-target, swiftlint]
---

## What

`SlideDurationResponse.toDomain`, `TransitionTypeResponse.toDomain`, and `SlideshowConfigResponse.toDomain` are UseCase-internal helpers that convert Response enums back to Domain types. Because the app is a single target, these `internal` methods are technically callable from Presentation, violating layer boundaries.

## Do

- Rely on SwiftLint custom rules and arch rule documentation as the primary guardrail
- Consider Swift Package modularization if stricter enforcement becomes necessary

## Don't

- Call `toDomain` from Presentation — it is a UseCase-internal conversion helper
- Treat `internal` visibility as equivalent to "UseCase-scoped" in a single-target build
