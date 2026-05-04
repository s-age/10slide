---
name: PHPhotoLibrary.requestAuthorization vs authorizationStatus
description: Checking authorizationStatus without requesting throws notAuthorized on first launch; always use requestAuthorization
type: reference
---

## Problem

Calling `PHPhotoLibrary.authorizationStatus(for:)` and checking for `.authorized` / `.limited` throws immediately on first launch because the status is `.notDetermined` — the permission dialog has never been shown.

```swift
// Bad — throws notAuthorized on first launch
let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
guard status == .authorized || status == .limited else {
    throw ImageDataSourceError.notAuthorized  // always thrown on first run
}
```

## Fix

Use `requestAuthorization(for:)` which shows the system dialog when status is `.notDetermined`, and returns immediately (without UI) when already determined:

```swift
// Good — requests permission if not yet determined
let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
guard status == .authorized || status == .limited else {
    throw ImageDataSourceError.notAuthorized
}
```

## Also Required

`INFOPLIST_KEY_NSPhotoLibraryUsageDescription` must be set in the target's build settings (via `project.yml` when using XcodeGen) for the system to show the dialog at all. Without it, the authorization request silently fails.

```yaml
settings:
  base:
    INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "Select photos for your slideshow"
```
