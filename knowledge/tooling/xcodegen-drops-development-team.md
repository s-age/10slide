---
type: problem
context: when running xcodegen generate and then trying to build or sign the app
keywords: [XcodeGen, DEVELOPMENT_TEAM, code signing, pbxproj, project.yml, build settings]
---

## What

`xcodegen generate` strips `DEVELOPMENT_TEAM` from both Debug and Release build configurations
in `project.pbxproj`. The setting is not present in `project.yml` (XcodeGen only emits what it
knows about), so XcodeGen has no value to write. Result: build fails immediately:

```
Signing for '10slide' requires a development team.
```

The `GENERATE_INFOPLIST_FILE` setting survives regeneration; `DEVELOPMENT_TEAM` does not.

## Do

After `xcodegen generate`, manually restore the setting in both configurations:
```
DEVELOPMENT_TEAM = 7VF2T8G76X;
```

Or add it to `project.yml` so XcodeGen includes it on every generation:
```yaml
settings:
  base:
    DEVELOPMENT_TEAM: 7VF2T8G76X
```

For pipeline builds that skip signing, pass overrides instead:
```bash
xcodebuild CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO ...
```

## Don't

- Don't assume `DEVELOPMENT_TEAM` survives regeneration — always verify after `xcodegen generate`.
- Don't commit a `project.pbxproj` missing `DEVELOPMENT_TEAM` if local signing builds are expected.
