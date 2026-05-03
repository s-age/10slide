# .task modifier vs Task {} in SwiftUI

## Problem

A common pattern is to kick off async work in `onAppear`:

```swift
.onAppear {
    Task { await viewModel.load() }   // Bad
}
```

This `Task` is not tied to the view's lifetime. If the view disappears before the task completes (e.g. the user navigates back), the task keeps running and may write to a deallocated ViewModel.

## Solution

Use the `.task` view modifier. It starts an async task when the view appears and **automatically cancels it when the view disappears**.

```swift
// Good — auto-cancelled on disappear
.task {
    await viewModel.load()
}
```

For tasks that should re-run when a value changes, use `.task(id:)`:

```swift
// Re-runs whenever selectedID changes; cancels the previous run first
.task(id: selectedID) {
    await viewModel.loadDetail(id: selectedID)
}
```

## Decision guide

| Situation | Use |
|-----------|-----|
| Load data when view appears | `.task { }` |
| Reload when a binding/state value changes | `.task(id:) { }` |
| Fire-and-forget work not tied to view lifetime | `Task { }` (e.g. logging, analytics) |
| Work that must survive navigation (e.g. upload) | `Task { }` stored in a long-lived object |

## Key detail

`.task` is cancellation-cooperative — the async work must check `Task.isCancelled` or call cancellable APIs (most `async` system APIs already do this) to actually stop early. Cancellation is a request, not a forced stop.
