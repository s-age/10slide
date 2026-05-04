---
type: problem
context: when renaming or retyping a SwiftData @Model property between app launches
keywords: [SwiftData, migration, @Model, column rename, type change, VersionedSchema, MigrationStage]
---

## What

Renaming or changing the type of a `@Model` property breaks SwiftData's automatic lightweight
migration. The app (or tests with a persistent `ModelContainer`) crash at launch:

```
Fatal error: DI initialization failed: SwiftDataError(_error: loadIssueModelContainer)
Validation error missing attribute values on mandatory destination attribute
```

SwiftData sees the renamed property as a new non-optional attribute (no value in old rows) and
the old name as a deleted attribute — lightweight migration cannot bridge this automatically.

## Do

**Dev recovery** — delete the persistent store and let the app recreate it:
```bash
rm ~/Library/Application\ Support/default.store
```

**Production** — use a `VersionedSchema` + `MigrationStage` to supply default values for renamed
or retyped columns:
```swift
enum AppSchemaV1: VersionedSchema { ... }
enum AppSchemaV2: VersionedSchema { ... }
// MigrationStage provides default value for the new mandatory column
```

## Don't

- Don't rename a `@Model` property and expect automatic migration to succeed.
- Don't change a property from optional to non-optional without a migration stage.
- Adding new properties **with default values** is safe and migrates automatically — only renames
  and type changes break it.
