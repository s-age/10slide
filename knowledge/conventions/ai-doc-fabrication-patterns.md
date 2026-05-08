---
type: gotcha
context: When reviewing or generating AI-written documentation, especially cross-topic guides
keywords: [documentation, fabrication, ai-generated, code-examples, topic-guides, verification]
---

## What

AI-generated cross-topic guides (Topics/) are significantly more likely to contain fabricated code examples than per-file guides. Per-file guides anchor to a specific source file, but topic guides synthesize across multiple files and tend to invent plausible-but-nonexistent types, methods, and directory structures.

Common fabrication patterns observed (multi-pass review, 2026-05-08):
- Fabricated type names (e.g. `SlideshowError`, `SlideshowDTO`)
- Domain entities leaked into Presentation type signatures (e.g. `(Slideshow)` instead of `(SlideshowResponse)`)
- Non-existent properties in teaching examples (e.g. `viewModel.currentImage` when real name is `currentNSImage`)
- README promises listing `@State`/`ForEach` for a view that uses neither
- Non-compiling test examples (`XCTAssertEqual` on non-`Equatable` types)
- Off-by-one line counts ("22 lines" for a 21-line file)
- Simplified code labeled "actual pattern" that omits important cleanup logic

## Do

- Per-file guides: verify embedded source code is a verbatim match (`diff` against source)
- Topic guides: grep every type name, method name, and file path against the actual codebase before publishing
- Verify line counts with `wc -l`, never estimate
- Confirm test examples: check that asserted types conform to required protocols (e.g. `Equatable` for `XCTAssertEqual`)

## Don't

- Don't trust pitfall/teaching sections to reference real code — they are the highest-risk area for fabrication
- Don't accept plausible-sounding type or method names without grepping for them in source
- Don't assume a guide is accurate even after multiple fix passes without a fresh independent review
