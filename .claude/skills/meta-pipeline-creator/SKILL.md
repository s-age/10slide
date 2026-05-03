---
name: meta-pipeline-creator
description: Pipeline generation agent. Reads a plan file or directory and generates an implementation pipeline YAML file. Provides pipeline authoring rules for file naming, task naming, nested pipelines, rejection loops, and commit tasks.
---

# Planning Pipeline Creator Agent

You are a pipeline generation agent. Your sole job is to read a plan file (or plan directory) and generate an implementation pipeline YAML file from it.

```mermaid
flowchart TD
    Start([Start]) --> Check{plan path provided?}
    Check -- No --> Abort([Abort: ask for plan path])
    Check -- Yes --> CheckPattern

    CheckPattern{"pattern specified?\n(implement-feature / implement-unit-test /\nimplement-integration-test / review-fix / lint-fix /\noptimize-skills / optimize-knowledge)"}
    CheckPattern -- No --> AbortPattern(["Abort: ask which pattern\n\nAll implement patterns share the same structure\n(see examples/implement__feature-name.yaml);\nthey differ only in skills:\n\n  implement-feature        — new feature from plan\n    implementer: no skill (write detailed task)\n    reviewer:    review-arch\n\n  implement-unit-test      — unit test writing\n    implementer: implement-unit-test\n    reviewer:    review-test\n\n  implement-integration-test — integration test writing\n    implementer: implement-integration-test\n    reviewer:    review-arch\n\n  review-fix  — existing code review + fix loop\n               initial-review → fix-loop pipeline → commit\n               see examples/review-fix__layer__target.yaml\n\n  lint-fix    — SwiftLint rule violation fixes (no review agent)\n               pipeline(implement → build gate) → commit\n               see examples/lint-fix__layer__target.yaml\n\n  optimize-skills   — improve skill documentation files\n               implement → review → custom validate gate → commit per skill\n               domain-specific skills (improve-skill / review-skill)\n               see examples/optimize__skills__target.yaml\n\n  optimize-knowledge — audit/reorganize knowledge files\n               parallel agents per domain (no reviewer, no nested pipeline)\n               generic commit agent at end (not a session resume)\n               see examples/optimize__knowledge__target.yaml"])
    CheckPattern -- Yes --> Detect

    Detect{Is input a .md file\nor a directory?}
    Detect -- ".md file" --> FlatRead
    Detect -- "directory" --> DirRead

    FlatRead["STEP 1a — Read the flat plan file\nRead the .md file directly.\nExtract layers from the ## Files section\n(each numbered entry is one layer).\nUse ## 作業順序 for implementation order if present."]
    FlatRead --> Step3

    DirRead["STEP 1b — Read the manifest\nRead <plan_dir>/layers.md\nExtract the ordered layer rows (Order, Layer, Spec)"]
    DirRead --> Step2

    Step2["STEP 2 — Read each layer spec\nFor each row in layers.md (in Order):\n  Read <plan_dir>/<layer>.md\nNote files to create/modify and their I/F contracts"]
    Step2 --> Step3

    Step3["STEP 3 — Read gotchas\nIf directory: read <plan_dir>/gotchas.md if it exists\nNote any constraints that affect task boundaries or rejection strategy"]
    Step3 --> Step4

    Step4["STEP 4 — Determine task grouping\nGroup layers into nested pipelines.\nGroup rule: layers that must compile together go in the same group.\nTypically: one nested pipeline per layer row unless they share a build boundary.\n\nBranch by pattern (see examples/implement__feature-name.yaml for implement structure):\n\n  implement-feature / implement-unit-test / implement-integration-test\n    top-level cleanup script (rm -f .claude/tmp/<slug>-* for all groups)\n    for each group → nested pipeline:\n      1. implement agent  — skill by type (see SKILL.md table); or no skill + detailed task for feature\n      2. review agent     — skill by type; ng_output_path set; rejected.to → implement\n      3. script gate      — xcodebuild -scheme 10slide -destination 'platform=iOS Simulator,name=iPhone 16' build\n                            (add test subcommand for test patterns)\n                            rejected.to → implement; max_retries: 3\n    after each group → commit agent (reuses implement agent name, outside that pipeline)\n\n  review-fix\n    top-level cleanup script (rm -f .claude/tmp/<slug>-* files)\n    for each group:\n      1. initial reviewer  — skill: review-arch; ng_output_path set (outside loop)\n      2. nested fix-loop pipeline:\n           a. fix implementer  — skill: refactor-arch; reads ng_output_path\n           b. loop reviewer    — SAME name as initial reviewer (resume); rejected.to → fix implementer\n           c. script gate      — xcodebuild ... build; rejected.to → fix implementer\n      3. commit agent (reuses fix implementer name, outside pipeline)\n\n  lint-fix\n    for each group → nested pipeline:\n      1. implement agent   — task lists files and SwiftLint rule; no skill\n      2. script gate       — xcodebuild ... build; rejected.to → implement\n    after all groups → commit agent (reuses implement agent name, outside pipeline)\n\n  optimize-skills\n    top-level cleanup script (rm -f .claude/tmp/<slug>-* for all targets)\n    for each skill → nested pipeline:\n      1. implement agent  — skill: improve-skill; ng_output_path set\n      2. review agent     — skill: review-skill; rejected.to → implement\n      3. script gate      — custom validation command (e.g. validate.sh); rejected.to → implement\n    after each skill → commit agent (reuses implement agent name, outside pipeline)\n\n  optimize-knowledge\n    one agent per knowledge domain — each reads a report and applies changes; no reviewer\n    agents run at top level (parallel fan-out, no nested pipeline)\n    final generic commit agent (name: optimize-knowledge-committer; does NOT resume an implementer)"]
    Step4 --> Step5

    Step5["STEP 5 — Write the pipeline\nDerive output path from the plan slug and pattern:\n  flat file: plans/chat-command.md  →  pipelines/<pattern>__chat-command.yaml\n  directory: plans/chat-command/    →  pipelines/<pattern>__chat-command.yaml\nUse YAML format (.yaml). Write the pipeline file."]
    Step5 --> Step6

    Step6["STEP 6 — Validate\nRun all three scripts (from project root):\n  bash ${CLAUDE_SKILL_DIR}/scripts/validate-name.sh pipelines/<name>.yaml\n  node ${CLAUDE_SKILL_DIR}/scripts/validate-schema.cjs pipelines/<name>.yaml\n  node ${CLAUDE_SKILL_DIR}/scripts/validate-child-paths.cjs pipelines/<name>.yaml\n\nAlso verify manually:\n- Every layer from the plan has a corresponding implement task\n- Every rejected.to names an existing task in the same scope"]
    Step6 --> Valid{All scripts pass\nand manual checks OK?}
    Valid -- No --> Fix[Fix the malformed pipeline]
    Fix --> Step6
    Valid -- Yes --> Done

    Done(["Done: print summary\n  Pipeline: pipelines/<pattern>__<slug>.yaml\n  Run with: perclst run pipelines/<pattern>__<slug>.yaml"])
```

## Pattern × skill table

| Pattern | Implementer skill | Reviewer skill |
|---|---|---|
| implement-feature | _(none — write detailed task)_ | review-arch |
| implement-unit-test | implement-unit-test | review-test |
| implement-integration-test | implement-integration-test | review-arch |
| review-fix | refactor-arch | review-arch |
| lint-fix | _(none)_ | _(none)_ |
| optimize-skills | improve-skill | review-skill |
| optimize-knowledge | _(none)_ | _(none)_ |

## Build gate commands

```bash
# Build only
xcodebuild -scheme 10slide -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build + test (for unit-test and integration-test patterns)
xcodebuild -scheme 10slide -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Consult `examples/` in this skill directory for reference YAML files.
