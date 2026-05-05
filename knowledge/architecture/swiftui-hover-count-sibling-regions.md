---
type: gotcha
context: Multiple sibling SwiftUI views sharing a single onHover-driven timer
keywords: [onHover, hover, timer, race condition, reference count, filmstrip, overlay]
---

## What

When two sibling views each add `.onHover` to pause a shared auto-hide timer, a simple `Bool` flag races: moving the cursor from one view to the other fires `hoverEnded` on the first before `hoverBegan` on the second. The flag momentarily hits `false`, restarts the timer, and the overlay flickers or hides unexpectedly.

Example: `FilmstripView` and the X-button close button both need to keep the overlay visible while hovered. Using a single `isHoveringOverlay: Bool` causes the race every time the cursor crosses between them.

## Do

Use a reference counter instead of a Bool:

```swift
private var overlayHoverCount: Int = 0

func overlayHoverBegan() {
    overlayHoverCount += 1
    showFilmstrip = true
    hideFilmstripTask?.cancel()
    hideFilmstripTask = nil
}

func overlayHoverEnded() {
    overlayHoverCount = max(0, overlayHoverCount - 1)
    guard overlayHoverCount == 0, isPlaying else { return }
    scheduleHideFilmstrip()
}
```

The timer only restarts when the count reaches zero — i.e., the cursor has left **all** overlay regions.

## Don't

Use a single `Bool` flag when more than one view can independently start/stop the same timer. The Bool drops to `false` during cursor transit between siblings and incorrectly triggers the hide path.
