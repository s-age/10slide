---
type: problem
context: when an XcodeGen-generated project shows no destinations in the Xcode 26 IDE
keywords: [XcodeGen, Xcode26, objectVersion, pbxproj, destination-picker, deploymentTarget]
---

## What

XcodeGen 2.45.4 emits `objectVersion = 77` (the Xcode 16 value). Xcode 26's IDE silently fails to
populate the destination picker for projects with this version even though `xcodebuild` CLI still
builds them. Xcode 26 uses `objectVersion = 70` — the numbering is not monotonically increasing
across releases. Separately, Xcode 26 beta ships only iOS 26.5 simulator runtimes, so a deployment
target earlier than `26.0` also causes "No supported iOS devices".

**Diagnostic**: if `xcodebuild -showdestinations` lists simulators but the IDE picker is empty →
`objectVersion` mismatch. If `xcodebuild -showdestinations` also shows nothing → deployment target
/ runtime mismatch.

## Do

- After every `xcodegen generate`, patch `project.pbxproj`:
  ```bash
  sed -i '' 's/objectVersion = 77/objectVersion = 70/' 10slide.xcodeproj/project.pbxproj
  sed -i '' 's/preferredProjectObjectVersion = 77/preferredProjectObjectVersion = 70/' \
    10slide.xcodeproj/project.pbxproj
  ```
- Set `deploymentTarget.iOS: "26.0"` (or the installed runtime version) in `project.yml`.
- Set `xcodeVersion: "2650"` in `project.yml` options to write the correct `LastUpgradeCheck`.

## Don't

- Don't use `supportedDestinations: [iOS]` in `project.yml` as a fix — it changes `SDKROOT`
  settings but does not write the `supportedDestinations` array on `PBXNativeTarget` that Xcode 26
  needs.
- Don't forget to re-apply the `objectVersion` patch after every `xcodegen generate` regeneration.
- Don't skip the diagnostic step — the two root causes require different fixes.
