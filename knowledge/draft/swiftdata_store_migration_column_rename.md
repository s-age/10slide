---
name: SwiftData store migration fails on column rename in dev
description: Renaming or retyping a @Model property breaks automatic SwiftData migration; delete the store to recover in dev
type: reference
---

## Problem

When a SwiftData `@Model` property is renamed or its type changed (e.g., `defaultDuration: TimeInterval` → `durationRawValue: String`), launching the app or running tests that instantiate a persistent `ModelContainer` fails with:

```
Fatal error: DI initialization failed: SwiftDataError(_error: loadIssueModelContainer)
```

Underlying CoreData error:
```
Validation error missing attribute values on mandatory destination attribute
```

## Root Cause

SwiftData's lightweight automatic migration cannot handle a column rename or type change in a single step. It sees `durationRawValue` as a new non-optional attribute and `defaultDuration` as a deleted attribute — migration requires a value for the new mandatory column, which doesn't exist in old rows.

## Fix (dev)

Delete the persistent store:
```bash
rm ~/Library/Application\ Support/default.store
```

The app recreates an empty store on next launch.

## Fix (production)

Use a versioned schema with a `MigrationStage` to supply the default value:
```swift
enum AppSchemaV1: VersionedSchema { ... }
enum AppSchemaV2: VersionedSchema { ... }

let migrationPlan = AppMigrationPlan.self
// In stage: provide durationRawValue = "5" for existing rows
```

## When this happens

Any time a `@Model` property is:
- Renamed
- Changed in type
- Switched from optional to non-optional (or vice versa)

New properties with default values are safe and migrate automatically.
