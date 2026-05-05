---
type: gotcha
context: SwiftLint custom rule restricting a layer to Foundation-only imports
keywords: [swiftlint, custom_rules, regex, import, Foundation, submodule, negative lookahead, anchor]
---

## What

A SwiftLint custom rule using `^import (?!Foundation$).*` to restrict a layer to Foundation-only imports false-positives on `import Foundation.NSURL` (and any `Foundation.X` submodule import). The `$` anchor fails because the line continues after "Foundation".

## Do

Use a character-class after the module name to allow dot-submodule and end-of-token:

```
^import (?!Foundation([\. ]|$)).*
```

The same pattern applies to any single-module restriction — e.g., restrict to SwiftUI only:

```
^import (?!SwiftUI([\. ]|$)).*
```

## Don't

Use a bare `$` anchor immediately after the module name:

```
^import (?!Foundation$).*   # NG — rejects valid: import Foundation.NSURL
```
