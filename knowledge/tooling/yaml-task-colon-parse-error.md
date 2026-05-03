---
type: gotcha
context: when writing pipeline YAML task fields that contain colon-space sequences
keywords: [YAML, pipeline, colon, BLOCK_AS_IMPLICIT_KEY, parse-error, conventional-commits]
---

## What

A YAML `task:` field value containing `": "` (colon followed by space) written as an inline scalar
causes `YAMLParseError: Nested mappings are not allowed in compact mappings`
(code: `BLOCK_AS_IMPLICIT_KEY`). Conventional commit message examples such as `feat(layer): ...`
are a common trigger, especially in commit-agent task descriptions in `pipelines/` YAML files.

```yaml
# Bad — ": " in "feat(layer): ..." is parsed as a mapping key
- type: agent
  task: Implementation complete. Commit with message (e.g. feat(layer): ...).

# Good — block scalar sidesteps the issue
- type: agent
  task: |
    Implementation complete. Commit with message (e.g. feat(layer): ...).
```

## Do

- Always use a block scalar (`|`) for any `task:` value that might contain a colon.
- Run `validate-schema.cjs` before pushing — it detects this immediately.
- Include example files under `.claude/skills/meta-pipeline-creator/examples/` in schema
  validation (run during CI and skill updates).

## Don't

- Don't write conventional commit examples as inline YAML scalars — the `": "` pattern always
  breaks YAML parsing.
- Don't assume the error message clearly points to the colon; look for `BLOCK_AS_IMPLICIT_KEY` in
  the stack trace.
