# Cross-View Coordination via Parent View (HomeView as Coordinator)

When a child view needs to trigger state changes in a sibling view, route the
action through the shared parent view rather than letting children communicate
directly.

## Pattern used in HomeView

`SlideshowLibraryPanel` fires `onEdit(slideshow)` → `HomeView.handleEdit`
checks `createViewModel.hasUnsavedWork` → either calls `applyEdit` directly or
stores `pendingEditSlideshow` and raises a confirmation alert.

`HomeView` owns both `createViewModel` (used by `LibraryPickerView`) and the
`SlideshowLibraryPanel` callback, so it is the natural place to enforce the
"discard work?" guard without coupling the two sibling views to each other.

## Limitation: pre-selected identifiers may not be visible

`CreateSlideshowViewModel.loadSlideshow` pre-selects a slideshow's
`localIdentifier`s. These identifiers only highlight as selected in the photo
grid if the current folder happens to contain those same assets. There is no
error or visual feedback when identifiers don't match anything in the grid.

## Binding from optional state for confirmationDialog

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

This avoids a separate `Bool` flag by deriving presence from the optional
itself.
