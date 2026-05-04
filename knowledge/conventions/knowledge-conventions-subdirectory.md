---
type: decision
context: Categorizing meta-project or workflow conventions that don't fit architecture, testing, infrastructure, or tooling
keywords: [conventions, knowledge-base, workflow, meta-project, directory-structure]
---

## What

The four standard knowledge subdirectories (`architecture`, `testing`, `infrastructure`, `tooling`) cover code-level patterns. Meta-project conventions — rules about how the team works, how the knowledge base itself is maintained, or workflow agreements — don't belong in any of them. `knowledge/conventions/` is the canonical home for this category.

## Do

- Place meta-project and workflow conventions in `knowledge/conventions/`.
- Use type `decision` for convention entries (they represent design choices, not bugs or external facts).

## Don't

- Don't force workflow conventions into `architecture/` or `tooling/` — those cover code patterns and build tooling respectively, not team/process conventions.
