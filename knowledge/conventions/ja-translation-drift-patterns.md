---
type: gotcha
context: When syncing Japanese docs (docs/ja/) with corrected English source (docs/en/)
keywords: [japanese, translation, drift, documentation, code-blocks, sync, localization]
---

## What

When syncing `docs/ja/` with corrected `docs/en/`, recurring drift patterns cause Japanese docs to diverge from English source. Observed across all 14 guide documents (2026-05-08):

1. **Code block comments translated** — LLM translators convert Swift comments inside code fences to Japanese instead of copying them verbatim.
2. **Sections added to English missing in Japanese** — Structural additions (e.g. new file sections, decorator notes, `String(localized:)` principles) are not reflected in Japanese after English is corrected.
3. **Fabricated code differs between languages** — Japanese versions sometimes contain *different* fabrications than English (e.g. `SlideshowError` in `ja` vs a different wrong type in `en`), indicating independent generation rather than translation from the English source.
4. **Type names diverged** — Japanese docs use older or incorrect type names (e.g. `SwiftDataSlideshowRepository` instead of `SlideshowRepository`, `ImageService` instead of `ImageDomainService`).

## Do

- Always translate from the current English source; never regenerate Japanese independently
- Copy-paste code blocks verbatim — never re-type or translate comments inside code fences
- After correcting English docs, immediately sync the Japanese counterpart

## Don't

- Don't allow an LLM to regenerate Japanese docs from scratch — always translate from the English version
- Don't translate Swift code comments inside code fences
- Don't assume Japanese docs are in sync after English corrections without explicitly updating them
