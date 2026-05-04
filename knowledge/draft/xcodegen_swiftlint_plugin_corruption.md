# xcodegen corrupts SwiftLint build tool plugin configuration

When `xcodegen generate` regenerates `project.pbxproj`, it converts the SwiftLintBuildToolPlugin (a build tool plugin with `isPlugin = 1`) into a regular `SwiftLint` framework dependency. This breaks the build with error: "Missing package product 'SwiftLint'" — the only product the SwiftLint package exports is `SwiftLintBuildToolPlugin`, not `SwiftLint`.

## What happens

xcodegen:
1. Changes `productName = SwiftLintBuildToolPlugin` → `productName = SwiftLint`
2. Removes `isPlugin = 1` from the product dependency
3. Adds `SwiftLint in Frameworks` to `PBXFrameworksBuildPhase`
4. Removes the `PBXTargetDependency` section that points to the plugin
5. Moves the dependency from `dependencies` array to `packageProductDependencies` array

All of this is wrong because SwiftLint is a build tool plugin, not a framework.

## Workaround

Don't run `xcodegen generate` for source-file-only changes. The original `project.pbxproj` already uses a glob (`sources: - Sources`) that automatically picks up new `.swift` files.

If you must regenerate (e.g., for structural changes), manually patch the pbxproj afterward:
- Restore `productName = SwiftLintBuildToolPlugin` and add `isPlugin = 1`
- Remove the `SwiftLint in Frameworks` build file and reference
- Restore the `PBXTargetDependency` section
- Move SwiftLint back from `packageProductDependencies` to `dependencies`

## Why it matters

xcodegen doesn't understand Swift package build tool plugins. This is a tool limitation, not a code issue. Understanding the limitation prevents wasted debugging time when regenerating the project file.
