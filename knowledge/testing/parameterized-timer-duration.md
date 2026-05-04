---
type: decision
context: when a ViewModel has timer-based auto-hide or auto-advance behavior that tests must observe
keywords: [testing, timers, ViewModel, @Observable, Duration, testability, parameterize]
---

## What

ViewModels with time-based behavior (auto-hide, auto-advance, debounce) use a production duration
default injected via `init()`. Tests pass a short `Duration` so they complete in milliseconds
instead of seconds. Production behavior is unchanged — the default value is the real duration.

See `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift` (`filmstripHideDuration`).

## Do

Declare the duration as an `init` parameter with a production default:

```swift
init(
    ...,
    filmstripHideDuration: Duration = .seconds(3)  // production default
) {
    self.filmstripHideDuration = filmstripHideDuration
}
```

In tests, pass a short duration:

```swift
sut = SlideshowPlayerViewModel(..., filmstripHideDuration: .milliseconds(50))

func testHidesAfterDuration() async throws {
    sut.play()
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertFalse(sut.showFilmstrip)
}
```

## Don't

- Don't hardcode the production duration inside the method body — it blocks fast tests.
- Don't use `XCTestExpectation` with `fulfill()`; `async throws` tests and `Task.sleep` are simpler.
- Don't apply this to animation durations tests don't need to observe — only timer-fired state changes.
