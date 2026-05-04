# 10slide

A macOS slideshow app built as a Swift learning project, demonstrating Clean Architecture, SwiftUI, and SwiftData on macOS 26.

> **Name origin:** 「テンプレートプロジェクトを作ろうと思ったら、スライドショーアプリが出来上がった件」

## Overview

10slide lets you import photos and arrange them into timed slideshows. The primary goal of this project is to serve as a hands-on template for exploring Swift 6, SwiftUI, and layered architecture patterns — the slideshow app is the vehicle, not the destination.

## Architecture

Clean Architecture with per-layer DI containers.

```
Presentation → UseCases → Repositories → Infrastructure
                    ↕
               Domain/Entities
```

| Layer | Directory | Role |
|-------|-----------|------|
| Presentation | `Sources/Presentation/` | SwiftUI views and ViewModels |
| Use Cases | `Sources/UseCases/` | Business logic |
| Repositories | `Sources/Repositories/` | DTO ↔ entity conversion |
| Infrastructure | `Sources/Infrastructure/` | SwiftData, Photos framework, file I/O |
| DI | `Sources/DI/` | Per-layer containers wired in `Container.swift` |
| Domain | `Sources/Domain/` | Pure value types, no framework imports |

## Requirements

- macOS 26+
- Xcode 26+
- Swift 6.1

## Building

`10slide.xcodeproj/project.pbxproj` is not tracked in git because it contains developer-specific code signing settings. Before opening the project in Xcode, you need to configure it:

1. Open `10slide.xcodeproj` in Xcode.
2. Select the `10slide` target → **Signing & Capabilities**.
3. Set your **Team** and update the **Bundle Identifier** to one registered under your Apple Developer account.
4. Repeat for the `10slideTests` target.

```bash
# Build from the command line (after configuring signing)
xcodebuild -scheme 10slide -destination 'platform=macOS' build

# Run tests
xcodebuild -scheme 10slide -destination 'platform=macOS' test
```

## Dependencies

- [SwiftLint](https://github.com/realm/SwiftLint) — enforces code style and custom layer-dependency rules
- [Yams](https://github.com/jpsim/Yams) — YAML parsing for slideshow config
