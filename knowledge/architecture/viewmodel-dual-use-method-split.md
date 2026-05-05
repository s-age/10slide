---
type: gotcha
context: ViewModel method called by both an auto-play timer and user interaction needing different side effects
keywords: [viewmodel, responsibility, next, auto-play, user-triggered, side effect, overlay, presentation]
---

## What

When a ViewModel method is called from two contexts — an internal timer and a user gesture — and each context needs different side effects, the View is tempted to compensate by adding extra ViewModel calls after the shared method. This leaks implicit contracts into Presentation: the View now must remember that user-triggered navigation also requires a second call.

## Do

Split into two methods: a base method for internal use, and a user-triggered wrapper that adds the side effect:

```swift
// ViewModel
func next() async {
    // navigate — no overlay side effect (safe for auto-play timer)
}

func userDidNext() async {
    await next()
    showFilmstripOverlay()   // side effect belongs here, not in the View
}
```

Call `userDidNext()` from all user-facing entry points (key press, swipe, filmstrip button). The auto-play timer continues to call `next()` directly, so slides advance silently without flashing the overlay.

## Don't

Add a compensating ViewModel call in the View to handle a side effect that only applies to user-triggered contexts:

```swift
// View compensating for missing side effect — WRONG
Task { await viewModel.next() }
viewModel.userDidInteract()   // View shouldn't know this is required
```

Any time the View calls two ViewModel methods in sequence to complete one logical user action, that's a sign the second call's logic belongs inside the first method (or a wrapper).
