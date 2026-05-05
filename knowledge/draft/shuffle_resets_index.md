# Shuffle toggle index behaviour

**Category:** design-decision  
**Layer:** Presentation / SlideshowPlayerViewModel

## Decision

- **Shuffle ON**: `currentIndex` resets to 0 (start of the new random order).
- **Shuffle OFF**: the currently displayed slide's `id` is located in `slideshow.slides` and `currentIndex` is set to that position, so playback continues on the same slide in the original order.

## Why

Shuffle-on resets to 0 because the permutation is freshly generated — the old index is meaningless in the new order.

Shuffle-off restores position because the user expects to stay on the slide they're watching; silently jumping to slide 1 feels like a bug.

The key implementation detail: `currentSlide?.id` must be captured **before** `shuffledSlides` is cleared, otherwise `displayedSlides` switches to `slideshow.slides` and the computed property returns the wrong slide.

## Where

- `SlideshowPlayerViewModel.toggleShuffle()` — `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift`
