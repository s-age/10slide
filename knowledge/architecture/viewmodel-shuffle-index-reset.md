---
type: decision
context: SlideshowPlayerViewModel.toggleShuffle() — how currentIndex is managed when shuffle is toggled on or off
keywords: [shuffle, SlideshowPlayerViewModel, currentIndex, toggleShuffle, slideshow, shuffledSlides]
---

## What

When shuffle is toggled, `currentIndex` must be handled differently depending
on direction:

- **Shuffle ON** → reset `currentIndex` to `0` (start of the freshly generated
  random order; the old index is meaningless in the new permutation).
- **Shuffle OFF** → locate the currently displayed slide's `id` inside
  `slideshow.slides` and set `currentIndex` to that position, so playback
  continues on the same slide in original order.

Critical capture order: `currentSlide?.id` must be read **before**
`shuffledSlides` is cleared. Once `shuffledSlides` is `nil` the computed
`displayedSlides` property switches to `slideshow.slides`, making the old
computed `currentSlide` return the wrong slide.

Implementation lives in `SlideshowPlayerViewModel.toggleShuffle()` →
`Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift`.

## Do

- Capture `let id = currentSlide?.id` as the first line of `toggleShuffle()`
  before mutating any shuffle state.
- After clearing `shuffledSlides`, use `slideshow.slides.firstIndex(where: { $0.id == id })`
  to restore the position.
- Reset to `0` on shuffle-on — never try to preserve an index across a
  permutation boundary.

## Don't

- Don't read `currentSlide` after clearing `shuffledSlides` — `displayedSlides`
  will have already switched sources and the value is stale.
- Don't silently jump to slide 1 when turning shuffle off — users expect to
  remain on the slide they were watching.
