---
type: decision
context: XcodeGen was removed from the project in favour of Xcode Folder References (commit e37d2f3)
keywords: [xcodegen, folder-references, pbxproj, project.yml, convert-to-folder]
---

## What

`project.yml` and XcodeGen were retired at commit `e37d2f3` by migrating to Xcode 16's "Convert to Folder" feature. `Sources/` and `Tests/` are now registered in `project.pbxproj` as folder references — new files are picked up automatically with no codegen step. SwiftLint (`SwiftLintBuildToolPlugin`) and Yams remain as `XCRemoteSwiftPackageReference` entries in the pbxproj, unchanged.

The removal was driven by accumulated gotchas that undermined XcodeGen's main selling point (reproducible project from `project.yml`):
- `xcodegen generate` dropped `GENERATE_INFOPLIST_FILE` from the test target (see `xcodegen-drops-development-team.md`)
- Xcode 26 broke the SwiftLint plugin reference on every regeneration (see `xcodegen-xcode26-compatibility.md`)
- Every `xcodegen generate` rewrote the entire pbxproj, producing noisy diffs

The existing `knowledge/tooling/xcodegen-*.md` files are kept for historical context; they no longer apply to day-to-day development.

## Do

- Add new Swift files anywhere under `Sources/` or `Tests/` freely — Xcode resolves them via folder reference with no extra step.
- If you ever need to convert an Xcode group to a folder reference, use the Xcode Project Navigator: right-click the group → "Convert to Folder".

## Don't

- Run `xcodegen generate` — `project.yml` no longer exists and XcodeGen is not installed.
- Look for a CLI equivalent to "Convert to Folder" — it is Xcode-UI-only; there is no command-line path.
- Treat the retained `xcodegen-*.md` knowledge entries as current guidance — they document superseded behaviour.
