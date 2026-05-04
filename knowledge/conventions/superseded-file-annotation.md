---
type: decision
context: When a newer knowledge file explicitly replaces an older one in knowledge/
keywords: [knowledge, superseded, convention, frontmatter, annotation, archaeology]
---

## What

When a knowledge file is replaced by a newer one, annotate it with `superseded-by:` frontmatter
and a blockquote warning rather than deleting it. Deleting loses historical context; leaving it
unannotated misleads future developers into implementing the wrong pattern.

First applied when `knowledge/infrastructure/swiftdata-modelactor-pattern.md` replaced the
`Mutex<ModelContext>` split-read/write approach documented in
`knowledge/infrastructure/swiftdata-modelcontext-region-isolation.md`.

## Do

- Add `superseded-by:` frontmatter listing every replacement file by path:
  ```markdown
  ---
  type: <original-type>
  context: <original-context>
  keywords: [...]
  superseded-by:
    - knowledge/<dir>/<replacement1>.md
  ---
  ```
- Add a visible blockquote warning immediately after the frontmatter block (before `## What`):
  ```
  > ⚠️ **Superseded.** <One-sentence description of what replaced this and why>.
  > This file is retained for historical context only — do **not** implement this pattern.
  ```
- Keep the rest of the file body intact for historical reference.

## Don't

- Don't delete superseded files — the historical reasoning has archaeology value.
- Don't leave superseded files unannotated — a future developer will implement the wrong pattern.
- Don't mark a file superseded without listing the concrete replacement file(s).
