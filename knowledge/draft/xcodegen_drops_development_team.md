# xcodegen drops DEVELOPMENT_TEAM build setting

When `xcodegen generate` regenerates `project.pbxproj`, it strips the `DEVELOPMENT_TEAM` build setting from both Debug and Release configurations, even though `project.yml` doesn't explicitly override it.

## What happens

Original committed pbxproj has:
```
DEVELOPMENT_TEAM = 7VF2T8G76X;
GENERATE_INFOPLIST_FILE = YES;
```

After xcodegen regeneration, `DEVELOPMENT_TEAM` is missing while `GENERATE_INFOPLIST_FILE` remains. This causes build failure: "Signing for '10slide' requires a development team."

The setting is not in `project.yml` (xcodegen looks at the base settings there), so xcodegen doesn't know to preserve it.

## Solution

Add to both Release and Debug build configurations in `project.pbxproj` after regeneration:
```
DEVELOPMENT_TEAM = 7VF2T8G76X;
```

Or configure `project.yml` to specify this setting explicitly so xcodegen includes it.

## Why it matters

Without the development team setting, builds fail when running `xcodebuild` without code-signing overrides. This breaks pipeline builds that don't pass `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`.
