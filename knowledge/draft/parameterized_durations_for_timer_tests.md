---
name: Parameterize duration-based timers for testability
description: When a ViewModel has time-dependent auto-hide or auto-advance behavior, pass the duration as a constructor parameter with a production default to enable fast unit tests.
keywords: testing, timers, ViewModel, @Observable, filmstrip, testability
---

## Pattern

When a ViewModel manages a timer (e.g., auto-hide UI after inactivity), parameterize the duration in `init()` with a sensible production default:

```swift
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private let filmstripHideDuration: Duration

    init(
        slideshow: Slideshow,
        loadSlideImage: any LoadSlideImageUseCaseProtocol,
        filmstripHideDuration: Duration = .seconds(3)  // ← production default
    ) {
        self.slideshow = slideshow
        self.loadSlideImageUseCase = loadSlideImage
        self.filmstripHideDuration = filmstripHideDuration
    }

    func showFilmstripOverlay() {
        showFilmstrip = true
        hideFilmstripTask?.cancel()
        hideFilmstripTask = nil
        guard isPlaying else { return }
        hideFilmstripTask = Task {
            try? await Task.sleep(for: filmstripHideDuration)  // ← use the param
            guard !Task.isCancelled else { return }
            showFilmstrip = false
        }
    }
}
```

In tests, pass a short duration:

```swift
override func setUp() {
    super.setUp()
    sut = SlideshowPlayerViewModel(
        slideshow: ...,
        loadSlideImage: ...,
        filmstripHideDuration: .milliseconds(50)  // ← fast for tests
    )
}

func testShowFilmstripOverlay_whilePlaying_hidesAfterHideDuration() async throws {
    sut.play()
    try await Task.sleep(for: .milliseconds(100))  // ← minimal wait
    XCTAssertFalse(sut.showFilmstrip)
}
```

## Why

- **Avoids slow tests**: Without parameterization, you must wait for the real production duration (e.g., 3.1s for a 3s timer + safety margin). With parameterization, wait milliseconds.
- **Production behavior unchanged**: Default parameter = production default. No test-only hacks in production code.
- **Testable by design**: Encourages timers to be constructor-injected rather than hardcoded, which is more flexible anyway.

## When

Use this pattern when:
- A ViewModel has a timer or duration-based behavior (auto-hide, auto-advance, debounce)
- The real duration is seconds or minutes (wait time compounds in CI)
- Tests need to observe the timer firing (not just that it *can* fire)

Do NOT use if:
- The duration is truly immutable (e.g., a constant animation duration that tests don't observe)
- A mock timer or `XCTestExpectation` would be simpler
