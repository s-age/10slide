---
type: decision
context: when enforcing layer import constraints in a single-module Swift app
keywords: [SwiftLint, custom_rules, layer-enforcement, architecture, import, single-module]
---

## What

In a single-module Swift app all source files share one module (`TenSlide`), so Swift access
control cannot prevent a Presentation file from importing SwiftData or instantiating a Repository
directly. SwiftLint `custom_rules` with `included` path-regex and `regex` import-pattern fills
this gap — acting as a convention fence at lint time, analogous to ESLint `no-restricted-imports`
in TypeScript monorepos.

```yaml
custom_rules:
  domain_no_infrastructure_imports:
    included: "Sources/Domain/.*\\.swift"
    regex: "^import (SwiftData|Photos)"
    message: "Domain layer must not import infrastructure frameworks."
    severity: error
```

The alternative (separate SPM targets) provides compile-time guarantees but requires significantly
more project setup. The current project uses the SwiftLint approach for simplicity.

## Do

- Define one custom rule per prohibited import per layer, keyed on `included` path and `regex`.
- Set `severity: error` so violations fail CI rather than emitting warnings.
- Document each rule's intent with an inline comment in `.swiftlint.yml`.
- Consider SPM separate targets for stricter compile-time enforcement if the project grows.

## Don't

- Don't rely on SwiftLint rules to catch indirect coupling (type aliases, re-exports) — they match
  text, not resolved symbols.
- Don't skip the lint step after adding new files to a layer; the Xcode build phase runs SwiftLint
  automatically, but CI should run it independently too.
