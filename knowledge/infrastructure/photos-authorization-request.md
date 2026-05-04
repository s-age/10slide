---
type: gotcha
context: when accessing the Photos library permission status on first launch
keywords: [Photos, PHPhotoLibrary, requestAuthorization, authorizationStatus, notDetermined, Info.plist]
---

## What

`PHPhotoLibrary.authorizationStatus(for:)` returns `.notDetermined` on first launch — the user
has never been prompted. Checking the status and treating `.notDetermined` as unauthorized throws
`notAuthorized` on every first run. `requestAuthorization(for:)` shows the system dialog when
status is `.notDetermined` and returns immediately when already determined.

Also required: `INFOPLIST_KEY_NSPhotoLibraryUsageDescription` must be set in build settings or
the system silently ignores the authorization request.

## Do

Always use `requestAuthorization`:

```swift
let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
guard status == .authorized || status == .limited else {
    throw ImageDataSourceError.notAuthorized
}
```

In `project.yml`:
```yaml
settings:
  base:
    INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "Select photos for your slideshow"
```

## Don't

- Don't call `authorizationStatus(for:)` alone and guard on `.authorized` — it misses
  `.notDetermined` and breaks first-launch flow.
- Don't omit the `NSPhotoLibraryUsageDescription` key — the authorization dialog won't appear.
