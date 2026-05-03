# Pipeline runner overwrites pipeline YAML mid-execution

## Discovery

While a `pipelines/*.yaml` is being executed by the pipeline runner, the runner actively writes back to that file to track progress. Editing the YAML mid-run is futile — your changes get clobbered the next time the runner serializes its state.

Symptoms observed during the slideshow-playback pipeline run:

- An `Edit` (with `replace_all: true`) on the `xcodebuild` destination string reported "All occurrences were successfully replaced", but a subsequent `grep` showed the old value back. The runner had re-flushed its in-memory snapshot.
- A nested agent inside the pipeline tried the same `replace_all` and got the same misleading success-then-revert. It eventually fell back to `sed` and got a 0-replacement count too.

## What the runner adds / changes when it writes

- Appends `done: true` to every completed task (and to the enclosing pipeline once all subtasks are done).
- Re-serializes scalar block styles, e.g. `task: |` (literal) → `task: >` (folded). Folded form joins paragraph lines, which can subtly change embedded shell commands if they relied on hard line breaks.
- Drops author-written comments (`# ═══ Layer N ═══` section dividers were lost on re-write).

## How to apply

- **Never edit a pipeline YAML while it is running.** Abort the pipeline first (`^Q`), make the edit, then re-run.
- Before committing pipeline YAML, diff against `HEAD` to make sure runner-generated `done: true` markers and reformatted block styles aren't being committed as part of the canonical definition. The fastest reset is `git checkout HEAD -- <file>` then re-apply only the intentional change (e.g., via `perl -i -0pe`).
- The same caution applies to any in-pipeline agent that tries to "fix the YAML for itself" — its edit will lose to the runner. The fix has to come from outside, after abort.

## Why it matters

This bit me during the iOS→macOS destination fix. I tried to update `'platform=iOS Simulator,name=iPhone 16'` → `'platform=macOS'` while the pipeline was running, both directly and via a sub-agent inside the pipeline. Both attempts looked successful and then silently reverted, sending the user down a confusing diagnostic path. The right move was to abort the pipeline first.
