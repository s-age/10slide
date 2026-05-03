---
type: gotcha
context: when starting async work from SwiftUI views
keywords: [SwiftUI, task, async, cancellation, onAppear, view-lifetime]
---

## What

A `Task {}` created inside `.onAppear` is not tied to the view's lifetime. If the view disappears
before the task completes, the task keeps running and may write to a deallocated ViewModel.

The `.task` view modifier starts an async task on appear and automatically cancels it when the
view disappears. `.task(id:)` additionally re-runs (and cancels the previous run) whenever the
id value changes.

| Situation | Use |
|-----------|-----|
| Load data when view appears | `.task { }` |
| Reload when a binding/state value changes | `.task(id:) { }` |
| Fire-and-forget work not tied to view lifetime | `Task { }` (e.g. logging, analytics) |
| Work that must survive navigation (e.g. upload) | `Task { }` stored in a long-lived object |

## Do

- Use `.task { }` to load data when a view appears — it is automatically cancelled on disappear.
- Use `.task(id: value) { }` when work should re-run whenever a value changes.
- Reserve bare `Task { }` for fire-and-forget work or work that must outlive the view.

## Don't

- Don't create `Task { await viewModel.load() }` inside `.onAppear` — the task outlives the view.
- Don't assume `.task` forcibly stops work — cancellation is cooperative; the async work must check
  `Task.isCancelled` or call cancellable system APIs to actually stop early.
