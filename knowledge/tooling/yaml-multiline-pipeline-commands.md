---
type: gotcha
context: editing pipeline YAML files that contain long shell commands wrapped across multiple lines
keywords: [yaml, pipeline, multiline, block-scalar, edit, write, xcodebuild, command]
---

## What

Pipeline task commands that exceed line length are sometimes formatted with YAML block
scalar syntax, splitting the command across two or more lines in the file. The YAML
parser reconstructs these as a single command at runtime, but the literal bytes in the
file span multiple lines. Tools like `Edit` (which do exact string matching) will fail
to find the pattern if the split point is unexpected.

## Do

- Write all pipeline build commands on a single line, even when they are long.
- When you must edit an already-wrapped command, use `Write` to rewrite the entire
  file rather than `Edit` for targeted replacement.

## Don't

- Don't use YAML block scalar (`>` or `|`) or bare line-wrap to break long shell
  commands across multiple lines in pipeline YAML.
- Don't attempt `Edit`-based targeted replacement on a command that is already
  wrapped across lines — the match will silently fail.
