---
type: gotcha
context: when a @MainActor ViewModel async method spans multiple awaits that may complete out of order
keywords: [ViewModel, async, concurrency, index-snapshot, stale-write, race-condition, MainActor, task-detached]
---

## What

`.task(id:)` automatically cancels the previous task when `id` changes. When the same async
work is moved into a ViewModel `@MainActor` method instead, that automatic cancellation is
lost. Rapid consecutive calls (e.g. next/prev navigation) can result in an older async result
completing after a newer one and overwriting `currentNSImage` with stale data.

`Task.detached` `await`s are also MainActor suspension points — another write can complete
while the background decode is in flight. Guarding only after the fetch is therefore not enough.

## Do

Snapshot the index before the first `await`; guard after **every** `await` point:

```swift
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex                        // snapshot before any await

    do {
        let data = try await loadSlideImageUseCase.execute(...)
        guard currentIndex == expectedIndex else { return } // guard after fetch

        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        guard currentIndex == expectedIndex else { return } // guard after decode

        currentNSImage = image
    } catch {
        currentNSImage = nil
    }
}
```

`currentIndex` changes on every `next()` / `jumpTo()` call, so a mismatched snapshot reliably
detects stale results. This gives the same "only the latest call wins" semantics as `.task(id:)`.

## Don't

- Don't guard only after the initial fetch — `Task.detached` `await` is also a suspension
  point where `currentIndex` can advance.
- Don't assume moving logic from `.task(id:)` into a ViewModel method preserves cancellation
  behavior — it doesn't; add explicit index guards instead.
- Don't skip the snapshot pattern for any async ViewModel method that reads an index or cursor
  and performs multiple `await`s before writing back to `@Observable` state.
