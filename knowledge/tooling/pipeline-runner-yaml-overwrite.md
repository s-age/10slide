---
type: gotcha
context: when editing a pipeline YAML file while the pipeline runner is executing it
keywords: [pipeline, YAML, runner, overwrite, done, block-scalar, mid-run-edit]
---

## What

The pipeline runner writes back to its `pipelines/*.yaml` file during execution to track progress.
Any edit made mid-run is silently overwritten on the runner's next state flush. Side effects of
runner re-serialization:

- Appends `done: true` to every completed task (and to the enclosing pipeline once all subtasks
  finish).
- Converts `task: |` (literal block scalar) → `task: >` (folded), which can subtly change
  embedded shell commands that rely on hard line breaks.
- Drops author-written comments (e.g. `# ═══ Layer N ═══` section dividers).

The same problem affects sub-agents running inside the pipeline — their edits also lose to the
runner flush, even when the edit reports "successfully replaced".

## Do

- Abort the pipeline first (`^Q`), then edit the YAML, then re-run.
- Before committing pipeline YAML, diff against `HEAD` to strip runner-generated `done: true`
  markers and reformatted block styles. Use `git checkout HEAD -- <file>` then re-apply only the
  intentional change (e.g. via `perl -i -0pe`).

## Don't

- Don't edit a pipeline YAML while it is running — the edit will be silently overwritten.
- Don't rely on a sub-agent inside the pipeline to "fix the YAML for itself" — its edit loses to
  the runner for the same reason.
- Don't commit `done: true` markers or runner-reformatted block styles as part of the canonical
  pipeline definition.
