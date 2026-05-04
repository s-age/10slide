---
type: gotcha
context: Modifying dependencies, types, or injection patterns that appear in .claude/rules/ sample code
keywords: [rules, sample-code, drift, .claude/rules, DI, maintenance, arch-repositories, arch-di]
---

## What

Sample code in `.claude/rules/` files is managed independently of the live codebase and is not updated automatically when the implementation changes. Stale "Good" examples in rule files will be treated as correct patterns by future Claude sessions, potentially re-introducing removed or renamed dependencies.

This surfaced when `SlideRepository` had an unused `imageDataSource` dependency removed: `arch-repositories.md` and `arch-di.md` still showed that injection as a canonical example.

## Do

Whenever a dependency is added, removed, or renamed, scan the relevant `.claude/rules/` files and update any sample code that references it.

## Don't

- Don't assume rule files stay in sync automatically after refactoring.
- Don't leave outdated "Good" examples in rule files — they actively mislead future code generation.
