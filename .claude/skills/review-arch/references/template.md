# Code Review Report -- Template

Use this format for all output from the review-arch skill.

`<CHECK>` is one of:
- Architecture: `FORBIDDEN_IMPORT` | `RESPONSIBILITY` | `DI_CONSISTENCY` | `PROTOCOL_PLACEMENT`
- Security: `HARDCODED_SECRET` | `FORCE_UNWRAP` | `UNCHECKED_SENDABLE` | `UNSANITIZED_INPUT`
- Performance: `N_PLUS_1` | `SYNC_MAIN_ACTOR` | `REPEATED_CONTEXT` | `UNBOUNDED_ITERATION`

---

```
# Code Review Report -- <target_path>
Reviewed: <YYYY-MM-DD>

## Summary

Clean  (or)  N violation(s) found  [Architecture: X | Security: Y | Performance: Z]

## Architecture

No violations  (or list violations below)

### [<CHECK>] `<file_path>`:<line> -- <short description>

**layer:** `<layer>`
**check:** <check>

<Full description of what rule is broken and why, with a code excerpt if it aids clarity.>

**Recommendation:** <What to change and where the code belongs.>

---

## Security

No issues  (or list violations below)

### [<CHECK>] `<file_path>`:<line> -- <short description>

**check:** <check>

<Full description of the risk, with a code excerpt if it aids clarity.>

**Recommendation:** <How to fix.>

---

## Performance

No issues  (or list violations below)

### [<CHECK>] `<file_path>`:<line> -- <short description>

**check:** <check>

<Full description of the bottleneck, with a code excerpt if it aids clarity.>

**Recommendation:** <How to fix.>
```

**Rules:**
- Summary MUST NOT include file count ("across N files") or a list of scanned files
- Omit a section entirely (including its heading) when it has no violations
- For the refactor agent: apply all code changes first, run `xcodebuild build` once only after all edits are complete
