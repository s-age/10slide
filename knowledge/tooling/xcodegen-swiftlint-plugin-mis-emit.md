---
type: problem
context: when XcodeGen mis-emits the SwiftLint build tool plugin as a library product
keywords: [XcodeGen, SwiftLint, plugin, pbxproj, isPlugin, PBXTargetDependency, packageProductDependencies]
---

## What

XcodeGen 0.23.x treats a `plugin: SwiftLintBuildToolPlugin` dependency in `project.yml` as a
library product. It emits the entry in `PBXFrameworksBuildPhase` and `packageProductDependencies`
with `productName = SwiftLint` and no `isPlugin` flag.

Xcode requires build tool plugins to be:
- An `XCSwiftPackageProductDependency` with `isPlugin = 1` and the real plugin product name.
- Referenced from the target's `dependencies` array via a `PBXTargetDependency` with `productRef`.
- **Not** present in any `PBXBuildFile` or `PBXFrameworksBuildPhase`.

Result: `xcodebuild` fails with `error: Missing package product 'SwiftLint'` after every fresh
`xcodegen generate`. The SwiftLint package exposes no library product named `SwiftLint` — only
`SwiftLintBuildToolPlugin` (plugin), `SwiftLintCommandPlugin` (plugin), and `SwiftLintFramework`
(library).

See `xcodegen-swiftlint-plugin-pbxproj-fix.md` for the five-step manual patch.

## Do

- After every `xcodegen generate`, apply the manual `pbxproj` patch (see companion file).
- Verify with `xcodebuild -scheme 10slide -destination 'platform=macOS' build`.
- Consider avoiding full `xcodegen generate` for source-file-only changes; edit `pbxproj` by hand
  for those to avoid reintroducing the regression.

## Don't

- Don't use `productName = "plugin:SwiftLintBuildToolPlugin"` with the `plugin:` prefix alone —
  it still fails without `isPlugin = 1` and routing through `PBXTargetDependency`.
- Don't leave the plugin entry in `packageProductDependencies` or `PBXFrameworksBuildPhase` —
  Xcode rejects that shape for build tool plugins.
