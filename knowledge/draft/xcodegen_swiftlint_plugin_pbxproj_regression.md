---
name: xcodegen breaks SwiftLint build-tool-plugin config
description: When regenerating project.pbxproj, xcodegen converts SwiftLintBuildToolPlugin to framework build file; requires manual fix
type: reference
---

## Problem

Running `xcodegen generate` after adding new source files breaks the SwiftLint build-tool-plugin configuration in `project.pbxproj`:

**Before (correct):**
```
E9FA4287D14793472D024978 /* SwiftLintBuildToolPlugin */ = {
    isa = XCSwiftPackageProductDependency;
    isPlugin = 1;
    package = 354922C3878C679388476A6F /* ... */;
    productName = SwiftLintBuildToolPlugin;
};
```

**After xcodegen (broken):**
```
E9FA4287D14793472D024978 /* SwiftLint */ = {
    isa = XCSwiftPackageProductDependency;
    package = 354922C3878C679388476A6F /* ... */;
    productName = SwiftLint;
};
```
Plus bogus `SwiftLint in Frameworks` build file entries.

Result: `xcodebuild` fails with "Missing package product 'SwiftLint'".

## Root Cause

xcodegen's handling of the `plugin:` dependency type in `project.yml` doesn't generate the correct pbxproj references. The plugin is treated as a regular framework dependency instead of a build-tool plugin.

## Fix

After running `xcodegen generate`, manually restore the SwiftLint plugin configuration:

1. Remove the bogus `SwiftLint in Frameworks` PBXBuildFile entry
2. Remove `SwiftLint in Frameworks` from the PBXFrameworksBuildPhase
3. Add the SwiftLint plugin to the 10slide target's `dependencies:` (as a PBXTargetDependency)
4. Remove `SwiftLint` from the 10slide target's `packageProductDependencies`
5. Restore `isPlugin = 1` and `productName = SwiftLintBuildToolPlugin` in XCSwiftPackageProductDependency

(See commit 54a9239 for the exact pbxproj edits.)

## Workaround

Avoid running `xcodegen generate` unless structurally necessary (e.g., adding top-level directories). When adding new `.swift` files to existing directories, xcodegen's glob picks them up, but requires manual pbxproj restoration afterward.

Alternatively: manually add file references to pbxproj instead of re-running xcodegen.
