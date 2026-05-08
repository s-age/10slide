# SlideshowPlayerViewModel — Swift Concepts Guide

**Target file**: `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift`

**Overview**: A ViewModel that manages the playback state of a slideshow. It handles play, pause, next, and previous operations, and coordinates asynchronous image loading, shuffling, slide duration and transition updates, filmstrip (thumbnail list) show/hide behavior, and fullscreen hint display -- all within this single class.

---

## Table of Contents

1. [`import Observation` — The Observation Framework](#1-import-observation--the-observation-framework)
2. [`@Observable` — Observable Class](#2-observable--observable-class)
3. [`@MainActor` — Main Actor](#3-mainactor--main-actor)
4. [`final class` — Non-Inheritable Class](#4-final-class--non-inheritable-class)
5. [`private(set)` — Externally Read-Only Properties](#5-privateset--externally-read-only-properties)
6. [Nested `enum` (FullscreenHintType)](#6-nested-enum-fullscreenhinttype)
7. [`any Protocol` — Existential Type](#7-any-protocol--existential-type)
8. [`async` / `await` — Asynchronous Processing](#8-async--await--asynchronous-processing)
9. [`Task { }` / `Task.isCancelled` — Structured Concurrency](#9-task---taskiscancelled--structured-concurrency)
10. [`Task.sleep(for:)` — Async Sleep](#10-tasksleepfor--async-sleep)
11. [`Task.detached(priority:)` — Detached Task](#11-taskdetachedpriority--detached-task)
12. [`guard` Statement — Early Return](#12-guard-statement--early-return)
13. [`defer { }` — Deferred Execution](#13-defer---deferred-execution)
14. [`try` / `do-catch` — Error Handling](#14-try--do-catch--error-handling)
15. [Task-Based Timer Pattern](#15-task-based-timer-pattern)
16. [Pitfalls Learned in Practice](#16-pitfalls-learned-in-practice)
17. [What You Can Learn from This File — Summary](#17-what-you-can-learn-from-this-file--summary)

---

## 1. `import Observation` — The Observation Framework

### What It Is

`import Observation` imports the **Observation framework** introduced by Apple in Swift 5.9. This framework provides a mechanism that "automatically notifies observers (such as SwiftUI Views) when an object's properties change."

### Why It Is Used Here

It enables automatic redrawing of SwiftUI views when ViewModel properties (`isPlaying`, `currentNSImage`, etc.) change. Without `import Observation`, the `@Observable` macro used below would not be available.

### What Happens Without It

You would need to fall back to the older `ObservableObject` + `@Published` combination (discussed later).

```swift
import Observation  // <- Without this, @Observable cannot be used
```

---

## 2. `@Observable` — Observable Class

### What It Is

`@Observable` is a Swift macro (a mechanism that auto-generates code at compile time). When applied to a class, it **automatically tracks access to all `var` properties** and tells SwiftUI Views to "please redraw" when values change.

### Why It Is Used Here

`SlideshowPlayerViewModel` has many properties that Views use for display, such as `isPlaying` and `currentNSImage`. `@Observable` makes the entire class "observable" so that Views automatically update whenever these properties change.

### Difference from `ObservableObject`

| Comparison | `@Observable` (new) | `ObservableObject` (old) |
|------------|---------------------|--------------------------|
| Introduced in | Swift 5.9 / iOS 17 | iOS 13 |
| Declaration effort | Just add `@Observable` to the class | Must add `@Published` to each property |
| Tracking precision | Redraws only for **properties actually accessed** | Redraws the entire View when any `@Published` property changes |
| View-side syntax | Simply receive with `let` or `@Bindable var` | Requires `@ObservedObject` or `@StateObject` |

### What Happens Without It

```swift
// Old style (ObservableObject)
class SlideshowPlayerViewModel: ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentNSImage: NSImage?
    // ... @Published required on every property
}
```

```swift
// New style (@Observable) -- this file's approach
@Observable
final class SlideshowPlayerViewModel {
    private(set) var isPlaying: Bool = false
    private(set) var currentNSImage: NSImage?
    // @Published is not needed
}
```

```swift
// The relevant section in this file
@Observable
@MainActor
final class SlideshowPlayerViewModel {
```

---

## 3. `@MainActor` — Main Actor

### What It Is

`@MainActor` is a declaration that "guarantees all code in this class runs on the main thread (the UI thread)." In Swift, an **actor** is "a safe execution context that runs only one piece of code at a time," and `MainActor` is a special actor dedicated to the main thread.

### Why It Is Used Here

SwiftUI Views **must be updated from the main thread**. Since `@Observable` triggers View updates when properties change, property writes also need to happen on the main thread. By applying `@MainActor` to the entire class, you guarantee that "any method called on this class runs on the main thread."

### What Happens Without It

If you accidentally write to properties from a background thread during async processing, crashes or unexpected rendering bugs can occur. The Swift 6 compiler detects these as errors, so without `@MainActor`, many locations would produce compile errors.

```swift
@Observable
@MainActor  // <- Constrains the entire class to the main thread
final class SlideshowPlayerViewModel {
```

---

## 4. `final class` — Non-Inheritable Class

### What It Is

A class marked with `final` **cannot be subclassed (inherited)**. With `class SlideshowPlayerViewModel`, other classes could inherit via `class MyVM: SlideshowPlayerViewModel { }`, but `final class` makes that a compile error.

### Why It Is Used Here

There are two reasons:

1. **Communicates design intent**: The ViewModel is designed to be self-contained and is not intended to be extended through inheritance.
2. **Performance optimization**: When `final` is present, the compiler can resolve method calls via static dispatch (jumping directly to the function address), which is slightly faster.

### What Happens Without It

Without `final` (`class SlideshowPlayerViewModel`), it would still work, but the design rule "this class should not be inherited" would not be visible in the code.

```swift
final class SlideshowPlayerViewModel {  // final = no inheritance allowed
```

---

## 5. `private(set)` — Externally Read-Only Properties

### What It Is

`private(set)` is an access control that means "**reading is OK from outside, but writing is only allowed from within the class**."

| Modifier | From within the class | From outside the class |
|----------|----------------------|----------------------|
| `var` | Read/write | Read/write |
| `private var` | Read/write | Cannot read or write |
| `private(set) var` | Read/write | **Can read, cannot write** |

### Why It Is Used Here

Views need to **read** `isPlaying` and `currentNSImage` for display purposes, but **must not modify them directly** (modifications should go through methods like `play()` or `pause()`). `private(set)` lets the compiler enforce this rule.

### What Happens Without It

Using `var isPlaying: Bool = false` would allow Views to write `viewModel.isPlaying = true`, making it easy to introduce bugs that bypass the ViewModel's logic.

```swift
private(set) var slideshow: SlideshowResponse   // Readable from outside, not writable
private(set) var currentIndex: Int = 0
private(set) var isPlaying: Bool = false
private var shuffledSlides: [SlideResponse]?    // Not readable or writable from outside
```

---

## 6. Nested `enum` (FullscreenHintType)

### What It Is

An `enum` (enumeration) is "a type that lists all possible values in advance." In this file, an `enum` called `FullscreenHintType` is defined **inside** the class. This is called a **nested type**.

```swift
enum FullscreenHintType: Equatable {
    case enter   // Hint to enter fullscreen
    case exit    // Hint to exit fullscreen
}
```

### What `Equatable` Means

`: Equatable` is a promise that "this type can be compared with the `==` operator." Since `FullscreenHintType` has only two cases, Swift automatically generates the `==` implementation.

### Why It Is Defined Inside the Class

`FullscreenHintType` is a type used only by `SlideshowPlayerViewModel`, so there is no need to expose it externally. Defining it inside the class signals "this type is exclusive to this class." When you need to reference it from outside, you write `SlideshowPlayerViewModel.FullscreenHintType`.

### What Happens Without enum

```swift
// Bad: Representing kinds with strings means typos become runtime errors
var fullscreenHint: String? = "enter"   // "entter" wouldn't be caught

// Good: With enum, non-existent values cause compile errors
var fullscreenHint: FullscreenHintType? = .enter
```

```swift
// An enum nested inside the class
enum FullscreenHintType: Equatable {
    case enter
    case exit
}

private(set) var fullscreenHint: FullscreenHintType? = nil
```

---

## 7. `any Protocol` — Existential Type

### What It Is

The `any` in `any LoadSlideImageUseCaseProtocol` means "a box that can hold **any type** conforming to this protocol." This is called an **existential type**. Since Swift 5.7, `any` must be written explicitly for existential types.

### Why It Is Used Here

The ViewModel needs "image loading functionality" but **does not need to know the specific implementation**. By depending on a protocol (a contract) rather than a concrete type, you can pass in a mock (fake) during testing and a real implementation in production. This is called **dependency injection**.

### Difference Without `any`

Before Swift 5.6, omitting `any` did not cause an error, but since Swift 5.7, adding `any` to existential types is recommended (and will become required in the future). Writing it explicitly communicates to readers that "an existential type, not a concrete type, is being used here."

```swift
// The ViewModel does not know the specific implementation class
private let loadSlideImage: any LoadSlideImageUseCaseProtocol
private let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
private let advanceSlide: any AdvanceSlideUseCaseProtocol
private let previousSlide: any PreviousSlideUseCaseProtocol
```

```swift
// Receives "some implementation" from outside via init
init(
    slideshow: SlideshowResponse,
    loadSlideImage: any LoadSlideImageUseCaseProtocol,  // <- Existential type
    ...
) {
    self.loadSlideImage = loadSlideImage
```

> **Note**: In this project, UseCase protocol type aliases embed `any` internally, so in the actual code, `any` may be omitted in some places. The compiler resolves this automatically.

---

## 8. `async` / `await` — Asynchronous Processing

### What It Is

`async` marks a function as "containing asynchronous work (it may take time to complete)," and `await` marks "waiting here for the async work to finish."

While waiting for completion, the thread is not blocked (occupied), allowing other work to proceed.

### Why It Is Used Here

Loading image data from disk or the photo library takes time. Using `await` keeps the UI from freezing during the load.

### What Happens Without It

With the traditional callback (closure) approach:

```swift
// Old style (callbacks)
func loadCurrentImage(completion: @escaping (NSImage?) -> Void) {
    loadSlideImage.execute(request) { result in
        switch result {
        case .success(let data):
            completion(NSImage(data: data))
        case .failure:
            completion(nil)
        }
    }
}
```

With `async/await`:

```swift
// New style -- this file's approach
func loadCurrentImage() async {
    let data = try await loadSlideImage.execute(request)
    currentNSImage = NSImage(data: data)
}
```

The nested callbacks (so-called "callback hell") are eliminated, resulting in straightforward, top-to-bottom code.

```swift
// Examples of async functions
func toggleShuffle() async { ... }
func next() async { ... }
func loadCurrentImage() async { ... }
```

---

## 9. `Task { }` / `Task.isCancelled` — Structured Concurrency

### What It Is

`Task { }` creates a **unit of asynchronous work**. When you want to call an `async` function but you are inside synchronous (non-async) code, you wrap it in `Task { }` to create an async context.

`Task.isCancelled` is a Bool property that checks "whether this task has been cancelled."

### Why It Is Used Here

The `play()` method is synchronous, but it needs to run an async loop that advances slides at regular intervals. That loop is written inside `Task { ... }`, and a reference to the task is saved in `timerTask` so it can be "cancelled later" -- creating a cancellable timer.

```swift
func play() {
    ...
    timerTask?.cancel()       // Cancel the previous timer if any
    timerTask = Task {        // Create and save a new timer task
        while !Task.isCancelled, isPlaying {   // Loop while not cancelled
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                break         // Break if sleep is cancelled
            }
            guard !Task.isCancelled, isPlaying else { break }
            await next()
        }
    }
}
```

### Why `Task.isCancelled` Is Needed

Calling `timerTask?.cancel()` does not immediately stop "the code currently executing inside the task." It is the task's own responsibility to respond to the cancellation request. By checking `Task.isCancelled`, you implement "exit the loop if cancelled" yourself.

### Why the Task Is Stored in a Variable

```swift
private var timerTask: Task<Void, Never>?
```

`Task<Void, Never>` means "a task with no return value (Void) and no errors (Never)." Storing it in a variable allows you to cancel it via `timerTask?.cancel()`. Without storing it, you would have a "fire-and-forget task" that cannot be cancelled.

---

## 10. `Task.sleep(for:)` — Async Sleep

### What It Is

`Task.sleep(for:)` is a method that "waits asynchronously for a specified duration." Unlike **synchronous sleeps** such as `Thread.sleep()` or `sleep()`, it does not block the thread while waiting (other work can continue). Additionally, if the task is cancelled, it immediately throws a `CancellationError` and exits.

### Why It Is Used Here

It is used as a "timer" to automatically advance slides at regular intervals.

```swift
try await Task.sleep(for: .seconds(duration))
```

`.seconds(duration)` creates a `Duration` value. `duration` is a `Double` representing the number of seconds each slide is displayed.

### Why `try` Is Required

`Task.sleep(for:)` throws a `CancellationError` when the task is cancelled. Calling a function that can `throw` requires `try`.

```swift
do {
    try await Task.sleep(for: .seconds(duration))  // Throws CancellationError on cancel
} catch {
    break   // Catch the error (cancellation) and exit the while loop
}
```

---

## 11. `Task.detached(priority:)` — Detached Task

### What It Is

`Task.detached` creates a task that is **detached (separated) from the current actor (execution context)**. A regular `Task { }` runs on the same actor as the caller (here, `@MainActor`), but `Task.detached` does not belong to any actor.

### Why It Is Used Here

`NSImage(data: data)` is an image decoding operation that can be time-consuming depending on the data size. Performing this heavy work on the main thread would cause UI stuttering. By using `Task.detached(priority: .userInitiated)`, image decoding happens in the background, and the result is retrieved via `.value` once complete.

```swift
let image = await Task.detached(priority: .userInitiated) {
    NSImage(data: data)   // Heavy work on a background thread
}.value                   // Await completion and extract the result
```

### What `priority: .userInitiated` Means

This sets the task's priority. Work triggered directly by user interaction (`.userInitiated`) runs at a high priority and receives more CPU time from the system.

### Comparison with Regular `Task`

```swift
// Regular Task -- when called from within MainActor, it stays on MainActor (occupying the UI thread)
Task { NSImage(data: data) }

// Task.detached -- detaches from MainActor and runs in the background
Task.detached(priority: .userInitiated) { NSImage(data: data) }
```

---

## 12. `guard` Statement — Early Return

### What It Is

`guard` is a construct that says "if the condition is not met, exit immediately." It is the inverse of `if` -- the `else` block executes when the condition is **false**. The `else` block must contain `return`, `break`, `continue`, or `throw`.

### Why It Is Used Here

It implements the early return pattern for "if preconditions are not met, do not continue."

```swift
// guard-based style (this file)
func play() {
    guard !displayedSlides.isEmpty else { return }
    guard let duration = slideshow.config.duration.seconds else { return }
    // Reaching here guarantees: slides exist & duration was obtained
    isPlaying = true
    ...
}
```

```swift
// if-based style (for comparison)
func play() {
    if !displayedSlides.isEmpty {
        if let duration = slideshow.config.duration.seconds {
            isPlaying = true
            ...  // <- Nesting gets deeper
        }
    }
}
```

Using `guard` keeps nesting shallow, aligning the "happy path" code at the left margin for better readability. Also, variables unwrapped with `guard let` (like `duration`) are available outside the `else` block.

```swift
// guard let -- combines Optional unwrapping with early return
guard let slide = currentSlide else {
    currentNSImage = nil
    return
}
// From here on, slide is guaranteed to be non-nil
```

---

## 13. `defer { }` — Deferred Execution

### What It Is

Code written inside a `defer { }` block is **guaranteed to execute last, no matter how the function exits** -- whether via `return`, `throw`, or normal completion.

### Why It Is Used Here

In this file, the pattern is applied within `loadCurrentImage()`, but the typical use case is resetting an `isLoading` flag (as shown in the architecture rules examples).

```swift
// Typical defer usage (for reference)
func load() async {
    isLoading = true
    defer { isLoading = false }  // Always resets to false no matter how we return
    do {
        slideshows = try await fetchSlideshows.execute(...)
    } catch {
        // Even if we return here, defer still executes
        return
    }
    // defer executes on normal completion too
}
```

### What Happens Without defer

```swift
func load() async {
    isLoading = true
    do {
        slideshows = try await fetchSlideshows.execute(...)
    } catch {
        isLoading = false   // <- Must also write it in the catch block (risk of forgetting)
        return
    }
    isLoading = false       // <- Must also write it for normal completion (duplication and omission risk)
}
```

With `defer`, you only write the reset logic once, eliminating the risk of forgetting it.

---

## 14. `try` / `do-catch` — Error Handling

### What It Is

Swift's error handling follows a "throw and catch" model:

- A function marked `throws` may throw an error
- Adding `try` before the call explicitly acknowledges "an error might occur"
- `do { } catch { }` catches and handles the error

### Why It Is Used Here

The UseCase's `execute()` is declared as `throws` (it may throw an error). When communication errors, data corruption, or validation failures occur, they are caught with `catch` and shown to the user as an `errorMessage`.

```swift
func updateDuration(_ duration: SlideDurationResponse) async {
    let request = UpdateSlideshowConfigRequest(...)
    do {
        slideshow = try await updateSlideshowConfig.execute(request)  // May throw an error
    } catch {
        errorMessage = error.localizedDescription  // Display the error to the user
    }
    if isPlaying { play() }
}
```

### `try?` — Converting Errors to Optional

`try?` returns `nil` when an error occurs, effectively ignoring the error.

```swift
// Validation failure is "a bug that the UI should have prevented,"
// so error details are unnecessary -> use try? to convert to Optional and unwrap with if let
if let nextIndex = try? advanceSlide.execute(request) {
    currentIndex = nextIndex
    await loadCurrentImage()
} else {
    pause()
}
```

Additionally, `showHint` uses `try?` even more concisely:

```swift
try? await Task.sleep(for: .seconds(3))
// The cancellation error can be safely ignored (we just need the task to end), so try? simplifies it
```

---

## 15. Task-Based Timer Pattern

### What It Is

This file does not use the `Timer` class. Instead, it adopts a **timer built purely with Swift Concurrency** by combining `Task` and `Task.sleep`.

### The Complete Pattern

```swift
// 1. Variables to hold references to tasks
private var timerTask: Task<Void, Never>?
private var hideFilmstripTask: Task<Void, Never>?
private var hideHintTask: Task<Void, Never>?

// 2. Start the timer (cancel any existing task first)
func play() {
    timerTask?.cancel()
    timerTask = Task {
        while !Task.isCancelled, isPlaying {
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch { break }
            guard !Task.isCancelled, isPlaying else { break }
            await next()
        }
    }
}

// 3. Stop the timer
func pause() {
    timerTask?.cancel()
    timerTask = nil
}
```

```swift
// One-shot delayed execution timer (hide the filmstrip after N seconds)
private func scheduleHideFilmstrip() {
    hideFilmstripTask = Task {
        try? await Task.sleep(for: filmstripHideDuration)
        guard !Task.isCancelled else { return }
        showFilmstrip = false
    }
}
```

### Comparison with the `Timer` Class

| Comparison | `Timer` (old) | Task-based (this file) |
|------------|---------------|------------------------|
| Thread | Registered on a RunLoop (must be careful about the main thread) | Naturally on the main thread in a `@MainActor` class |
| Cancellation | `timer.invalidate()` | `task.cancel()` |
| Compatibility with `async` | Poor (requires callbacks) | Seamless (`await` works directly) |
| Memory management | RunLoop holds a reference, risking retain cycles | Follows standard ARC rules |

### The "Cancel Old Task Before Creating New One" Pattern

```swift
// showHint example
private func showHint(_ type: FullscreenHintType) {
    hideHintTask?.cancel()       // Cancel the previous hide-hint task
    fullscreenHint = type        // Show the hint immediately
    hideHintTask = Task {        // Create a new task to hide it after 3 seconds
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        fullscreenHint = nil
    }
}
```

If `showHint(.exit)` is called and then `showHint(.enter)` is called immediately after, the previous "hide after 3 seconds" task is cancelled and a new "hide after 3 seconds" task begins. Storing tasks in variables is essential for this "duplicate task prevention" pattern.

---

## 16. Pitfalls Learned in Practice

Here are pitfalls encountered during actual development related to this file.

### Pitfall 1: Anti-Pattern of Injecting @Observable ViewModel with @State

When passing an `@Observable` class to a View, receiving it with `@State(initialValue:)` means **only the initial value is stored, and any new instance the DI container provides afterward is ignored**. `@State` means "a value owned by this View," so SwiftUI caches it internally.

```swift
// BAD -- Instances passed on the second call onward are ignored
struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel
    init(viewModel: SlideshowPlayerViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
}
```

`@Observable` automatically tracks property access, so the View redraws without `@State`. For external injection, use `let` (read-only) or `@Bindable` (when two-way binding like `$vm.prop` is needed).

```swift
// GOOD -- For read-only, simply use let
struct SlideshowPlayerView: View {
    let viewModel: SlideshowPlayerViewModel
    init(viewModel: SlideshowPlayerViewModel) {
        self.viewModel = viewModel
    }
}

// GOOD -- Use @Bindable when bindings like $viewModel.prop are needed
struct LibraryPickerView: View {
    @Bindable var viewModel: CreateSlideshowViewModel
}
```

**Rule of thumb**: `@State` = a value the View creates and owns. Do not use it for externally injected `@Observable` instances.

---

### Pitfall 2: Index Race Conditions in Async Methods

The View's `.task(id:)` **automatically cancels the previous task** when the `id` changes. However, when you move the same logic into a ViewModel method, this automatic cancellation is lost. If the user rapidly taps "next," an older image load may complete after a newer one, **causing the display to revert to the previous slide**.

```swift
// BAD -- If currentIndex changes between the two awaits, the old image overwrites the new one
func loadCurrentImage() async {
    guard let slide = currentSlide else { return }
    do {
        let data = try await loadSlideImage.execute(...)
        // During this await, next() may have been called and currentIndex may have advanced
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        currentNSImage = image  // <- Overwrites with the old slide's image!
    } catch { ... }
}
```

The solution is to **snapshot the index before the await** and **check after each await that the index has not changed**.

```swift
// GOOD -- Snapshot and guard ensure "only the latest call wins"
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex                        // Snapshot

    do {
        let data = try await loadSlideImage.execute(...)
        guard currentIndex == expectedIndex else { return } // Guard 1

        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        guard currentIndex == expectedIndex else { return } // Guard 2

        currentNSImage = image
    } catch {
        currentNSImage = nil
    }
}
```

**Key point**: Check "am I still current?" after every `await`. In situations where you cannot rely on `.task(id:)` automatic cancellation, this snapshot-plus-guard pattern is essential.

---

### Pitfall 3: Do Not Hold NSImage Directly in the ViewModel

It is tempting to add an `NSImage?` property to the ViewModel, but `NSImage` is an `AppKit` type. This project's architecture rules **do not allow `import AppKit` in ViewModels**, so it would trigger a SwiftLint error.

On the other hand, calling `NSImage(data:)` synchronously inside the View's `body` blocks the main thread with image decoding, causing stuttering during slideshow playback.

```swift
// BAD -- Holding an AppKit type in the ViewModel violates architecture rules
@Observable
final class SlideshowPlayerViewModel {
    import AppKit  // <- SwiftLint error!
    private(set) var currentNSImage: NSImage?
}

// BAD -- Synchronous decoding in the View body blocks the main thread
var body: some View {
    if let data = viewModel.currentImage {
        Image(nsImage: NSImage(data: data)!)  // <- Causes UI stuttering
    }
}
```

The correct approach is to **have the ViewModel hold `Data?` and use `.task(id:)` + `Task.detached` on the View side for async decoding**.

```swift
// GOOD -- ViewModel holds only Data (no AppKit dependency)
@Observable
final class SlideshowPlayerViewModel {
    private(set) var currentImage: Data?
}

// GOOD -- View-side async decoding
struct SlideshowPlayerView: View {
    @State private var decodedImage: NSImage?

    var body: some View {
        // Display using decodedImage
    }
    .task(id: viewModel.currentImage) {
        guard let data = viewModel.currentImage else {
            decodedImage = nil; return
        }
        decodedImage = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
    }
}
```

**Benefits**: The ViewModel has no AppKit dependency. Decoding runs on a background thread, so the UI does not stutter. `.task(id:)` automatically cancels the previous decode when `data` changes.

---

## 17. What You Can Learn from This File — Summary

`SlideshowPlayerViewModel.swift` is a model example of combining modern Swift features to build a "safe and readable async UI controller."

| Concept | Role in This File |
|---------|-------------------|
| `@Observable` | Automatically notifies Views of property changes |
| `@MainActor` | Guarantees UI updates always happen on the main thread |
| `final class` | Prohibits inheritance and makes design intent explicit |
| `private(set)` | Compiler prevents unauthorized external writes |
| Nested `enum` | Confines the type to its scope and clarifies intent |
| `any Protocol` | Enables a swappable design independent of concrete implementations |
| `async / await` | Writes async code with synchronous-looking syntax |
| `Task { }` | Creates async contexts and manages task cancellation |
| `Task.sleep(for:)` | Waits without blocking the thread |
| `Task.detached` | Offloads heavy work from the main thread |
| `guard` | Precondition checks and early returns |
| `defer` | Guarantees cleanup at a single location upon exit |
| `try / do-catch` | Type-safe error propagation and handling |
| Task-based timer | Cancellable delayed and repeating operations |

### What This Design Teaches

- **State is centrally managed by the ViewModel**: All UI state -- `isPlaying`, `currentIndex`, `showFilmstrip`, etc. -- is consolidated here. Views only read state; modifications go through methods.
- **Async work must consider cancellation**: The pattern of storing `Task` in variables and calling `cancel()` before starting new work prevents "duplicate task launches."
- **Errors are surfaced upward**: UseCase errors are caught and converted to `errorMessage` for the View to display. The ViewModel does not silently swallow errors.
- **Thread boundaries are made explicit**: The deliberate use of `@MainActor` vs. `Task.detached` makes it clear from the code "which work runs on which thread."
