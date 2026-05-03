---
name: meta-rule-creator
description: Create or review a .claude/rules/*.md file. Use when writing a new rule or deciding unconditional vs conditional injection.
paths:
  - '.claude/rules/**'
---

Rules live at `.claude/rules/<name>.md` — one file per rule, flat structure (no subdirectories).

## Rule vs Skill

- **Rule**: inject constraints/knowledge silently when files are accessed — no user action required
- **Skill**: explicit workflow invoked by the user or triggered by file paths

If the guidance should fire automatically when Claude touches certain files, write a rule.
If it describes a multi-step workflow the user deliberately starts, write a skill.

## Rule types

| Type | Frontmatter | Injected when |
|:---|:---|:---|
| Unconditional | No `paths:` | Every request — always in system prompt |
| Conditional | `paths:` with globs | Matching files are accessed |

Default to **conditional**. Only use unconditional for truly global principles.

## Format

Conditional:
```yaml
---
paths:
  - 'Sources/**/*.swift'
---

Instructions start here — no header above this line.
```

Unconditional (omit the frontmatter block entirely):
```markdown
Instructions start here.
```

Frontmatter has **one allowed field**: `paths:`. Do not add `name:`, `description:`, or any other field.

## Naming

| Prefix | Use for |
|:---|:---|
| `arch-*.md` | Architecture and layer constraints |
| `test-*.md` | Testing conventions |
| `meta-*.md` | Tool/agent workflow rules |
| (no prefix) | Broad project-wide rules |

Good: `arch-usecases.md`, `test-unit.md`, `meta-plan.md`
Bad: `myRule.md`, `helper.md`, `stuff.md`

## Content guidelines

- Start with instructions immediately — no `## Goal`, `## Purpose`, or `## Overview` section
- **Unconditional**: <= 20 lines. Loaded on every request — ruthlessly brief.
- **Conditional**: <= 80 lines target. Loaded only on matching files — more detail is acceptable.
- State what Claude must **do**, not what the rule **is**
- Prohibitions use "Never X" or "Do not X" — not "Avoid X" (ambiguous)

## Steps

1. Decide: rule or skill? (see above)
2. Decide type: conditional (`paths:`) or unconditional (no `paths:`)
3. Choose a name following namespace prefix convention
4. Copy `template.md` to `.claude/rules/<name>.md`
5. Fill in frontmatter (conditional only) and write instructions
