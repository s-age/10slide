---
name: meta-skill-creator
description: Create or review a SKILL.md file. Use when writing a new skill, auditing an existing one, or unsure how to structure skill content.
auto-inject: false
paths:
  - '.claude/skills/**'
---

Write all skill content in **English**, regardless of the project's primary language.

## Naming

Skills live at `.claude/skills/<skill-name>/SKILL.md` — always one level deep, no nesting.

Choose a name with a **namespace prefix**:

| Prefix | Use for |
|:---|:---|
| `meta-*` | Skills about managing skills/agents/config |
| `arch-*` | Architecture and design pattern references |
| `test-*` | Testing conventions |
| `(no prefix)` | Broad, project-wide skills (`commit`, `review`, `deploy`) |

Good: `meta-skill-creator`, `arch-session-flow`, `implement-arch`
Bad: `helper`, `stuff`, `myskill`, `utils`

## Frontmatter fields

| Field | Notes |
|:---|:---|
| `name` | Lowercase, hyphens only, max 64 chars. Omit to use directory name. |
| `description` | **Most critical field.** Front-load the trigger phrase. Hard-truncated at 250 chars — put the essential signal in the first ~150 chars. |
| `paths` | Gitignore-style globs. Limits auto-activation to matching files. |
| `disable-model-invocation` | `true` prevents Claude from triggering the skill automatically — use for destructive actions. `false` (default) for reference and knowledge skills. |
| `user-invocable` | Omit (default) to allow users to call the skill with `/skill-name`. Set `false` for background knowledge only. |
| `auto-inject` | `false` excludes the skill from hook-based injection. Default `true`. |
| `allowed-tools` | Tools pre-approved while skill is active. Space-separated: `Bash(git *) Read`. |

## Content guidelines

- Start with instructions immediately — no "Goal" or "Purpose" section (that belongs in `description`)
- Target **50–100 lines** for `SKILL.md`; move large reference material to supporting files
- Use numbered lists for sequential steps, bullets for options or facts
- Write what Claude should **do**, not what the skill **is**
- Write **How**, never **What**

## Supporting files

Skills can ship additional files alongside `SKILL.md`:

```
my-skill/
├── SKILL.md          # Main instructions (required)
├── template.md       # Boilerplate for Claude to copy
├── examples/
│   └── sample.md     # Complete working example
└── references/
    └── catalog.md    # Reference data
```

This skill's own supporting files:
- `template.md` — copy this when creating a new skill
- `examples/arch-example.md` — complete, well-structured skill to reference

## Creating a new skill

1. Copy `template.md` to `.claude/skills/<your-skill-name>/SKILL.md`
2. Fill in frontmatter and instructions; consult `examples/arch-example.md` for reference
3. Add `template.md`, `examples/`, or `references/` as needed
