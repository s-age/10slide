---
type: external
context: step-by-step pbxproj patch to fix XcodeGen's mis-emitted SwiftLint plugin dependency
keywords: [XcodeGen, SwiftLint, pbxproj, isPlugin, PBXTargetDependency, patch, manual-fix]
---

## What

Five targeted edits to `10slide.xcodeproj/project.pbxproj` restore correct plugin wiring after
`xcodegen generate`. The correct shape: `XCSwiftPackageProductDependency` with `isPlugin = 1` and
`productName = SwiftLintBuildToolPlugin`, referenced from `dependencies` via a new
`PBXTargetDependency` with `productRef` (no `target` / `targetProxy`).

Both `isPlugin = 1` **and** routing through `PBXTargetDependency` are required — neither alone is
sufficient.

## Do

Apply these five edits in order:

1. **PBXBuildFile section** — delete the `SwiftLint in Frameworks` entry.
2. **PBXFrameworksBuildPhase** — remove the SwiftLint reference from `files = (...)`.
3. **PBXNativeTarget (10slide)**:
   - Remove SwiftLint from `packageProductDependencies = (...)`.
   - Add a new `PBXTargetDependency` ref to `dependencies = (...)`.
4. **XCSwiftPackageProductDependency** — rewrite the SwiftLint entry as:
   ```
   ID /* SwiftLintBuildToolPlugin */ = {
       isa = XCSwiftPackageProductDependency;
       isPlugin = 1;
       package = ... /* XCRemoteSwiftPackageReference "SwiftLint" */;
       productName = SwiftLintBuildToolPlugin;
   };
   ```
5. **PBXTargetDependency section** — add a new entry:
   ```
   NEW_ID /* PBXTargetDependency */ = {
       isa = PBXTargetDependency;
       productRef = ID /* SwiftLintBuildToolPlugin */;
   };
   ```
   Generate `NEW_ID`: `python3 -c "import os; print(os.urandom(12).hex().upper())"`

Verify: `xcodebuild -scheme 10slide -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`

## Don't

- Don't leave `productName = SwiftLint` — it must match the actual plugin product name.
- Don't add `target` or `targetProxy` to the new `PBXTargetDependency` — plugin deps use
  `productRef` only.
- Don't skip the PBXBuildFile and PBXFrameworksBuildPhase cleanup — leaving them causes a
  duplicate build phase error.
