# XcodeGen mis-emits SwiftLintBuildToolPlugin as a library product

## Problem

`project.yml` declares the SwiftLint plugin properly:

```yaml
dependencies:
  - plugin: SwiftLintBuildToolPlugin
    package: SwiftLint
```

But after `xcodegen generate` (XcodeGen 0.23.x), `xcodebuild` fails with:

```
error: Missing package product 'SwiftLint' (in target '10slide' from project '10slide')
```

XcodeGen emits the plugin dependency as if it were a library product named `SwiftLint`, which doesn't exist — the SwiftLint package only exposes `swiftlint` (executable), `SwiftLintFramework` (library), `SwiftLintBuildToolPlugin` (plugin), and `SwiftLintCommandPlugin` (plugin).

## Discovery — what XcodeGen writes vs. what Xcode wants

XcodeGen writes the plugin as:
- A `PBXBuildFile` linked into the target's `PBXFrameworksBuildPhase`
- An `XCSwiftPackageProductDependency` with `productName = SwiftLint` and **no** `isPlugin` flag
- Referenced from the target's `packageProductDependencies` array

Xcode actually wants build tool plugins represented as:
- An `XCSwiftPackageProductDependency` with `productName = <plugin name>` **and** `isPlugin = 1`
- Referenced from the target's `dependencies` array via a `PBXTargetDependency` whose `productRef` points to the plugin product (not via `packageProductDependencies`)
- **Not** present in any `PBXBuildFile` or `PBXFrameworksBuildPhase`

Source: XcodeGen's own `makePackagePluginDependency` function shows the correct shape (`isPlugin: true`, attached as `PBXTargetDependency(product: packageDependency)`), but that path is apparently not triggered by the `plugin: …` syntax in our `project.yml`. Possibly an XcodeGen bug or a syntax mismatch — needs investigation.

## Manual patch (5 edits to `10slide.xcodeproj/project.pbxproj`)

1. **PBXBuildFile section** — delete the `… /* SwiftLint in Frameworks */ = {isa = PBXBuildFile; productRef = … /* SwiftLint */; };` line.
2. **PBXFrameworksBuildPhase** — remove `… /* SwiftLint in Frameworks */,` from the target's `files = ( … )` array.
3. **PBXNativeTarget (10slide)**:
   - Remove the SwiftLint entry from `packageProductDependencies = ( … )`.
   - Add a new entry to `dependencies = ( … )` referencing a new PBXTargetDependency (created in step 5).
4. **XCSwiftPackageProductDependency** — change the SwiftLint entry to:
   ```
   ID /* SwiftLintBuildToolPlugin */ = {
       isa = XCSwiftPackageProductDependency;
       isPlugin = 1;
       package = … /* XCRemoteSwiftPackageReference "SwiftLint" */;
       productName = SwiftLintBuildToolPlugin;
   };
   ```
   Key: add `isPlugin = 1`; set `productName` to the actual plugin name (no quotes, no `plugin:` prefix).
5. **PBXTargetDependency section** — add a new entry referencing the plugin via `productRef` (no `target` / `targetProxy`):
   ```
   NEW_ID /* PBXTargetDependency */ = {
       isa = PBXTargetDependency;
       productRef = ID /* SwiftLintBuildToolPlugin */;
   };
   ```
   Generate `NEW_ID` with `python3 -c "import os; print(os.urandom(12).hex().upper())"`.

Verify with:

```bash
xcodebuild -scheme 10slide -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

## Things I tried that did NOT work

- `productName = "plugin:SwiftLintBuildToolPlugin"` (the `plugin:` prefix alone, without `isPlugin = 1`, leaving the entry in `packageProductDependencies`) — still fails with `Missing package product 'SwiftLintBuildToolPlugin'`.
- `productName = SwiftLintBuildToolPlugin` without `isPlugin = 1` — same failure.

The combination that works is `isPlugin = 1` **plus** routing through `dependencies` / `PBXTargetDependency` (not `packageProductDependencies`).

## Why it matters

Every `xcodegen generate` reintroduces this regression. Either:
- Patch `pbxproj` after each regenerate, or
- Avoid regenerating when only adding/removing source files (edit `pbxproj` by hand for those too — see `gotchas.md` pattern), or
- File / fix an XcodeGen bug so `plugin: …` in `project.yml` emits the `isPlugin = 1` shape.
