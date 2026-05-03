# SwiftLint custom rules as layer dependency enforcement

## Context

In TypeScript monorepos, tools like ESLint's `no-restricted-imports` rule can prevent one module from importing another, enforcing layer boundaries at lint time. TypeScript also supports separate `tsconfig.json` files per package to enforce this at the compiler level.

## The Swift single-module problem

In a standard iOS app, all source files compile into **one module** (`TenSlide`). Swift's access control (`internal`, `public`, `private`) cannot restrict which files within the same module import each other — there is no per-folder import boundary.

This means a Presentation-layer file can `import SwiftData` or instantiate a repository directly, and the compiler will not complain.

## Solution: SwiftLint custom rules

SwiftLint's `custom_rules` key supports per-file-path regex matching. By restricting specific `import` statements to specific directory paths, we can enforce the same constraints that TypeScript/ESLint provides.

Example from `.swiftlint.yml`:

```yaml
custom_rules:
  domain_no_infrastructure_imports:
    included: "Sources/Domain/.*\\.swift"
    regex: "^import (SwiftData|Photos)"
    message: "Domain layer must not import infrastructure frameworks."
    severity: error
```

This rule fires whenever a file under `Sources/Domain/` contains `import SwiftData` or `import Photos`.

## Limitation

SwiftLint custom rules match on **text**, not on resolved symbols. They will not catch indirect coupling (e.g. a type alias that re-exports a SwiftData type). They are a convention fence, not a compiler guarantee.

## Alternative: Swift Package Manager with separate targets

For stricter enforcement, each layer can be a separate SPM target with its own `Package.swift` dependency graph. A `Repositories` target that does not list `Infrastructure` as a dependency will fail to compile if it references any type from that target. This approach requires more project setup but gives compile-time guarantees. The current project uses the SwiftLint approach for simplicity.
