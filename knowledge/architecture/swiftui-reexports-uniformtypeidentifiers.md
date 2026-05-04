---
type: external
context: Writing Presentation-layer code that references UTType values (e.g. fileImporter)
keywords: [SwiftUI, UniformTypeIdentifiers, UTType, import, FORBIDDEN_IMPORT, allowlist]
---

## What

`SwiftUI` re-exports the `UniformTypeIdentifiers` module on Apple platforms. `UTType.image` and all other `UTType` values compile without an explicit `import UniformTypeIdentifiers`.

## Do

Rely on the SwiftUI re-export. When writing `fileImporter(allowedContentTypes:)` or any SwiftUI API that takes `[UTType]`, omit the explicit import:

```swift
import SwiftUI  // UTType is already in scope
```

## Don't

- Don't add `import UniformTypeIdentifiers` in Presentation-layer files — it triggers the SwiftLint `FORBIDDEN_IMPORT` rule (only `SwiftUI`, `Foundation`, `Domain/Entities`, and `UseCases/Protocols` are on the allowlist).
- Don't assume the import is needed just because the type lives in another module; SwiftUI's re-export makes it transparent.
