# XcodeGen output needs patching for Xcode 26 beta

## Symptom

Opening an XcodeGen-generated project in Xcode 26 beta shows:

> No supported iOS devices are available. Connect a device to run your application or choose a simulated device as the destination.

`xcodebuild -showdestinations` from the CLI lists every installed simulator correctly, and `xcodebuild build` succeeds. The discrepancy is between the CLI build system and the IDE's destination picker.

## Root causes

### 1. `objectVersion` numbering reversed in Xcode 26

The `objectVersion` field in `project.pbxproj` is **not** monotonically increasing across Xcode releases:

| Xcode | `objectVersion` |
|-------|-----------------|
| 14.x  | 56              |
| 15.x  | 60              |
| 16.x  | 77              |
| **26.x** | **70**       |

XcodeGen 2.45.4 emits `objectVersion = 77` (Xcode 16). Xcode 26's IDE silently fails to populate the destination picker for projects with this version, even though `xcodebuild` still parses them. Patch the file to `70` after generation.

### 2. Simulator runtime must satisfy the deployment target

Xcode 26 beta ships with iOS 26.5 simulator runtimes only. A deployment target of `iOS 18.0` (or anything earlier than the installed runtimes) produces the same "No supported iOS devices" error because no available simulator satisfies the minimum. Set `deploymentTarget.iOS` to `26.0` (or whatever matches the installed runtime) in `project.yml`.

### 3. XcodeGen `supportedDestinations` is not a fix

The `supportedDestinations: [iOS]` key in `project.yml` switches `SDKROOT` to `auto` and emits `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, but does **not** write a `supportedDestinations` array onto the `PBXNativeTarget` (which Xcode 26's destination resolution wants). Sticking with the older `platform: iOS` form is fine — the `objectVersion` patch is what unblocks the IDE.

## Working configuration

`project.yml`:

```yaml
options:
  xcodeVersion: "2650"        # sets LastUpgradeCheck
  deploymentTarget:
    iOS: "26.0"
targets:
  10slide:
    type: application
    platform: iOS
    settings:
      base:
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: "Apple Development"
```

After `xcodegen generate`, patch the pbxproj:

```bash
sed -i '' 's/objectVersion = 77/objectVersion = 70/' \
  10slide.xcodeproj/project.pbxproj
sed -i '' 's/preferredProjectObjectVersion = 77/preferredProjectObjectVersion = 70/' \
  10slide.xcodeproj/project.pbxproj
```

A development team must still be selected once in **Signing & Capabilities** (or set as `DEVELOPMENT_TEAM` in `project.yml`) before the IDE will build, even for simulator-only runs.

## Diagnostic distinction

When this error appears, distinguish the two cases first:

- `xcodebuild -showdestinations` shows simulators → IDE/format problem (the `objectVersion` issue).
- `xcodebuild -showdestinations` shows no simulators → runtime/deployment-target problem.
