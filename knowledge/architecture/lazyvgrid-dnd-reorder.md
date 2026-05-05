---
type: discovery
context: Implementing drag-and-drop reordering inside a LazyVGrid in the Presentation layer
keywords: [SwiftUI, LazyVGrid, drag-and-drop, Transferable, dropDestination, reorder]
---

## What

`String` conforms to `Transferable` natively — no custom conformance needed.
Attach `.draggable` + `.dropDestination` directly to each grid cell.
Use `remove(at:) + insert(at:)` — **not** `swapAt` — because the destination
index shifts after removal when moving forward in the array.

```swift
ForEach(items, id: \.self) { item in
    CellView(isDropTarget: dropTargetID == item)
        .draggable(item)
        .dropDestination(for: String.self) { dropped, _ in
            guard let dragged = dropped.first,
                  let from = items.firstIndex(of: dragged),
                  let to   = items.firstIndex(of: item),
                  from != to else { return false }
            let moved = items.remove(at: from)
            items.insert(moved, at: to)
            return true
        } isTargeted: { targeted in
            dropTargetID = targeted ? item : nil
        }
}
```

## Do

- Use `remove(at:) + insert(at:)` for both forward and backward moves.
- Track `dropTargetID: String?` at the parent level; pass `isDropTarget` into
  the cell for border-highlight feedback.
- Keep reorder in-memory until the user taps Save/Update — appropriate for an
  edit flow.

## Don't

- Don't use `swapAt` — it produces wrong results when moving an item forward
  (the destination index is off by one after removal).
- Don't add an `EditButton` or edit-mode environment for macOS; `.draggable`
  works by default without edit mode.
- Don't implement custom `Transferable` for `String` identifiers — native
  conformance already exists.
