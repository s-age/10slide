---
name: meta-knowledge-capture
description: Record a discovery, problem, or gotcha to knowledge/draft/. Use when you observe something worth remembering — a bug, a surprise behavior, an external fact, or a design decision.
paths:
  - 'knowledge/draft/**'
---

Write a freeform `.md` file to `knowledge/draft/`. The meta-librarian skill will structure and promote it later.

## What to capture

- **Problem** — something that broke, behaved unexpectedly, or caused confusion
- **Discovery** — how something actually works (vs. how you assumed)
- **External** — a fact from a library, tool, or API not obvious from the code
- **Decision** — a design choice made for a non-obvious reason

## How to write the draft

1. Create `knowledge/draft/<topic-slug>.md`
2. Write freeform — no required format, just enough detail to be useful later
3. Include: what happened, what file/function/component was involved, why it matters

## Rules

- Never write directly to `knowledge/` subdirectories — `draft/` only
- One file per distinct topic; don't bundle unrelated discoveries
- Freeform is fine — meta-librarian will structure it later
