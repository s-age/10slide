---
type: decision
context: When a child view needs to trigger state changes in a sibling view
keywords: [coordinator, parent-view, sibling, HomeView, state-management, confirmationDialog]
---

## What

Route cross-sibling actions through the shared parent view rather than coupling sibling views directly. `HomeView` acts as a coordinator: `SlideshowLibraryPanel` fires `onEdit(slideshow)` → `HomeView.handleEdit` checks `createViewModel.hasUnsavedWork` → either calls `applyEdit` directly or stores `pendingEditSlideshow` and raises a confirmation alert.

`HomeView` owns both `createViewModel` (used by `LibraryPickerView`) and the `SlideshowLibraryPanel` callback, making it the natural enforcement point for the "discard work?" guard.

A useful pattern when driving `confirmationDialog` from an optional: derive the `isPresented` binding from the optional itself rather than adding a separate `Bool` flag.

```swift
.confirmationDialog(
    "Delete \"\(pendingItem?.name ?? "")\"?",
    isPresented: Binding(
        get: { pendingItem != nil },
        set: { if !$0 { pendingItem = nil } }
    ),
    titleVisibility: .visible
) { ... }
```

## Do

- Place shared guard logic (e.g. "unsaved work?") in the parent view that already owns both affected view models.
- Derive `isPresented` for confirmation dialogs directly from an optional state value.

## Don't

- Don't let sibling views reach into each other's view models or call each other's handlers directly.
- Don't add a parallel `Bool` flag when an optional already encodes presence.
