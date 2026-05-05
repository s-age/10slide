# 10slide

SwiftUI slideshow app for macOS (Swift 6.1, macOS 26).

## Overview

Lets users select photos and arrange them into timed slideshows.

## Architecture

Strict one-way layered architecture with per-layer DI containers.

```
Presentation → UseCases → Domain/Services → Repositories → Infrastructure
               (Request/       ↑
                Response)  Domain/Entities
                           Errors (shared leaf — all layers may reference)
```

Each layer communicates only with its immediate neighbor via protocol boundaries. No layer may skip.

When creating, editing, or reviewing files under `Sources/`: the `arch` rule and the rule for the target layer (`arch-presentation`, `arch-usecases`, etc.) are auto-injected from `.claude/rules/`. No manual loading needed.

## Layer Map

| Directory | Role |
|-----------|------|
| `Sources/App/` | Entry point — `@main`, boots root `Container` |
| `Sources/DI/` | DI containers — one per layer, wired in `Container.swift` |
| `Sources/Presentation/` | SwiftUI views and ViewModels (uses Response types only) |
| `Sources/UseCases/` | Request validation, Domain Service delegation, Entity→Response mapping |
| ` ├ Requests/` | Input DTOs with `validate()` — consumed by Presentation |
| ` └ Responses/` | Output DTOs — the only domain-concept types Presentation sees |
| `Sources/Domain/Services/` | Orchestrators — call Repository protocols, own business logic |
| `Sources/Domain/Entities/` | Pure structs — no framework imports |
| `Sources/Repositories/` | DTO ↔ entity conversion; protocol implementations |
| `Sources/Infrastructure/` | Raw I/O — SwiftData, Photos, network |
| `Sources/Errors/` | **Shared leaf** — pure error enums (`LocalizedError`), accessible from all layers |

## Development

```bash
# Build
xcodebuild -scheme 10slide -destination 'platform=macOS' build

# Test
xcodebuild -scheme 10slide -destination 'platform=macOS' test

# Lint (runs automatically as an Xcode build phase)
swiftlint lint --config .swiftlint.yml
```

> **After any `Sources/` change**: verify with `xcodebuild build`. SwiftLint runs automatically as a build phase.

## Key Files

- `Sources/DI/Container.swift` — Root container; boots all sub-containers in dependency order
- `Sources/App/TenSlideApp.swift` — `@main`; initializes `Container`, passes `modelContainer` to the SwiftUI environment
- `.swiftlint.yml` — SwiftLint config including custom layer-dependency enforcement rules
- `.claude/rules/*.md` — Auto-injected layer rules (path-triggered)
