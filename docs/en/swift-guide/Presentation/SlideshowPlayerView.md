# SlideshowPlayerView — Swift Concepts Guide

**Target file**: `Sources/Presentation/Views/SlideshowPlayerView.swift`

**Overview**: A View that plays a slideshow in full screen. It displays photos in sequence and supports keyboard, drag, and tap controls. It also handles showing/hiding the filmstrip (thumbnail list), transition animations, and fullscreen hint overlays.

---

## Table of Contents

1. [struct ... : View — The View Protocol](#1-struct--view--the-view-protocol)
2. [let vs var — Property Declarations](#2-let-vs-var--property-declarations)
3. [@escaping Closures — Closures That Outlive Their Scope](#3-escaping-closures--closures-that-outlive-their-scope)
4. [var body: some View — The body Property and the some Keyword](#4-var-body-some-view--the-body-property-and-the-some-keyword)
5. [ZStack / HStack — Layout Containers](#5-zstack--hstack--layout-containers)
6. [.ignoresSafeArea() — Safe Area](#6-ignoressafearea--safe-area)
7. [.frame() / .padding() — Layout Modifiers](#7-frame--padding--layout-modifiers)
8. [if let — Optional Binding](#8-if-let--optional-binding)
9. [.task { } — Async Task Modifier](#9-task---async-task-modifier)
10. [.onKeyPress() — Keyboard Events](#10-onkeypress--keyboard-events)
11. [.onTapGesture / .simultaneousGesture / DragGesture — Gestures](#11-ontapgesture--simultaneousgesture--draggesture--gestures)
12. [.animation() — Animation](#12-animation--animation)
13. [.transition() — Transition](#13-transition--transition)
14. [@ViewBuilder — View Builder Attribute](#14-viewbuilder--view-builder-attribute)
15. [AnyTransition — Type-Erased Transition](#15-anytransition--type-erased-transition)
16. [.onReceive(NotificationCenter...) — Observing Notifications](#16-onreceivenotificationcenter--observing-notifications)
17. [.onHover — Hover Events](#17-onhover--hover-events)
18. [Task { await ... } — Async Calls Inside Closures](#18-task--await---async-calls-inside-closures)
19. [.id() — Unique View Identity](#19-id--unique-view-identity)
20. [Pitfalls Learned in Practice](#20-pitfalls-learned-in-practice)
21. [What You Can Learn from This File — Summary](#21-what-you-can-learn-from-this-file--summary)

---

## 1. `struct ... : View` — The View Protocol

### What It Is

`struct SlideshowPlayerView: View` declares "define a struct named `SlideshowPlayerView` and make it conform to the `View` protocol."

A **protocol** is a collection of rules that says "please follow these requirements." The `View` protocol requires that you implement a `body` property. SwiftUI reads this `body` to render the screen.

### Why It Is Used Here

Every UI component in SwiftUI must conform to the `View` protocol. Conforming to `View` gives you access to SwiftUI modifiers and containers such as `ZStack` and `.task`.

### What Happens Without It

A struct that does not conform to `View` cannot be inserted into SwiftUI's view tree. It cannot have a `body` property, nor can it use modifiers like `.frame()`.

```swift
struct SlideshowPlayerView: View {   // Declares conformance to the View protocol
    // ...
}
```

---

## 2. `let` vs `var` — Property Declarations

### What It Is

`let` declares a **constant** (immutable once assigned), while `var` declares a **variable** (mutable after assignment).

### Why It Is Used Here

In this file, all input properties received by the View are declared with `let`.

```swift
let viewModel: SlideshowPlayerViewModel
let thumbnailViewModel: ThumbnailViewModel
let onBack: () -> Void
let onSpriteMode: ((Int) -> Void)?
```

These are **values passed in from outside the View**, and the View itself never needs to modify them. Using `let` makes the intent clear -- "this View will not mutate these values" -- and the compiler catches any accidental mutations.

On the other hand, `body` is declared as `var`. This is because the `View` protocol requires `var body`, which allows SwiftUI to recompute `body` each time state changes.

### What Happens If You Use `var` Instead of `let`

The code will compile, but it sends a misleading signal to readers that "this value might change." Choosing `let` to accurately convey intent is a Swift best practice.

---

## 3. `@escaping` Closures — Closures That Outlive Their Scope

### What It Is

When you store a closure (`{ }` -- an anonymous function) as a property or call it asynchronously, the `@escaping` attribute is required. It tells the compiler "this closure may live beyond (escape) the lifetime of the function call."

### Why It Is Used Here

```swift
init(
    viewModel: SlideshowPlayerViewModel,
    thumbnailViewModel: ThumbnailViewModel,
    onBack: @escaping () -> Void,          // @escaping
    onSpriteMode: ((Int) -> Void)? = nil   // Optional, so implicitly @escaping
) {
    self.onBack = onBack       // <- Stored as a property of the struct
```

`onBack` is stored as `self.onBack` after `init` finishes and is called later when a button is pressed. Because it "survives beyond the calling `init`," `@escaping` is required.

`onSpriteMode` has an `Optional` type (with `?`) yet omits `@escaping` because the compiler automatically treats Optional closures as escaping.

### What Happens Without `@escaping`

You get a compile error. Swift assumes by default that closures are only used during the function's execution (non-escaping), so it prohibits storing them in properties.

---

## 4. `var body: some View` — The body Property and the `some` Keyword

### What It Is

`body` is the required property demanded by the View protocol. You write "what to display on screen" here.

The `some` in `some View` is called an **opaque type**. It means "returns some specific type that conforms to `View`, but that type name is not exposed externally."

### Why It Is Used Here

The contents of `body` result in a complex type combining `ZStack`, `Color`, `Image`, `FilmstripView`, and more. Writing that type out as `ZStack<TupleView<(Color, some View, ...)>>` would be impractical. Writing `some View` lets you "leave the type details to the compiler."

```swift
var body: some View {
    ZStack(alignment: .bottom) {
        // ...
    }
    .animation(...)
    .task { ... }
}
```

### What Happens Without `some`

You would need to spell out the exact return type, making the code extremely complex. You would also need to rewrite it every time the type changes.

---

## 5. `ZStack` / `HStack` — Layout Containers

### What It Is

SwiftUI layout containers determine how multiple views are arranged.

| Container | Arrangement |
|-----------|-------------|
| `ZStack` | **Layers** views from back to front (Z-axis) |
| `HStack` | Arranges views **horizontally** from left to right (Horizontal) |
| `VStack` | Arranges views **vertically** from top to bottom (Vertical) |

### Why It Is Used Here

**ZStack**: A slideshow has a layered structure -- "a black background, an image on top of that, a filmstrip on top of that, and a hint overlay on top of everything." `ZStack` is ideal for this.

```swift
ZStack(alignment: .bottom) {
    Color.black          // Backmost layer: black background
        .ignoresSafeArea()

    slideImage           // Middle layer: slide image

    if viewModel.showFilmstrip {
        FilmstripView(...)   // Front layer: filmstrip (at the bottom)
    }
}
```

`alignment: .bottom` specifies bottom alignment instead of the default center alignment.

**HStack**: Used to arrange the "sprite mode button" and "close button" horizontally side by side.

```swift
HStack(spacing: 0) {
    if let onSpriteMode { Button { ... } }
    Button { onBack() } label: { ... }
}
```

### What Happens Without It

Without containers, you cannot arrange multiple views side by side. In SwiftUI, views must always be placed inside a container.

---

## 6. `.ignoresSafeArea()` — Safe Area

### What It Is

The **safe area** is the "safe display region" that does not overlap with system UI elements like notches, home indicators, or screen edges. By default, SwiftUI views are drawn only within the safe area.

Adding `.ignoresSafeArea()` makes the view extend to the screen edges, ignoring the safe area.

### Why It Is Used Here

The slideshow's black background needs to cover the entire screen. Without ignoring the safe area, gaps of non-black color (the system background) would appear around the notch area and screen edges.

```swift
Color.black
    .ignoresSafeArea()   // Extend black to the very edges of the screen
```

### What Happens Without It

On macOS the impact is minimal, but on iOS/iPadOS, colors other than black (the system background) would be visible around the notch and Dynamic Island area.

---

## 7. `.frame()` / `.padding()` — Layout Modifiers

### What It Is

In SwiftUI, you can chain `.modifierName()` calls on views to adjust their size, spacing, and appearance. These are called **modifiers**.

- `.frame(maxWidth:maxHeight:)` -- Specifies the preferred size of a view
- `.padding()` -- Adds spacing around a view

### Why It Is Used Here

```swift
slideImage
    .frame(maxWidth: .infinity, maxHeight: .infinity)  // Expand to the maximum available size
```

`maxWidth: .infinity` means "make the width as large as the parent view allows." This is used to expand the slide image to fill the entire screen.

```swift
Image(systemName: "xmark.circle.fill")
    .padding(16)   // Add 16 points of padding around the icon for a larger tap target
```

The button icon is small, so `.padding()` expands the tappable area.

### What Happens Without It

Without `.frame()`, the view shrinks to its minimum content size and does not fill the screen. Without `.padding()`, the icon sits flush against the edge and becomes hard to tap.

---

## 8. `if let` — Optional Binding

### What It Is

`Optional` (a `?` type) represents "a value that may or may not exist (nil)." `if let` is a construct that says "if there is a value, unwrap and use it; otherwise, skip."

### Why It Is Used Here

This file uses it in three places.

**1. Conditional display of the sprite mode button**

```swift
if let onSpriteMode {
    Button {
        onSpriteMode(viewModel.currentIndex)
    } label: { ... }
}
```

`onSpriteMode` is `((Int) -> Void)?` (an Optional closure). If it was not provided (`nil`), the button is not displayed.

**2. Fullscreen hint display**

```swift
if let hint = viewModel.fullscreenHint {
    fullscreenHintOverlay(hint)
}
```

The overlay is only shown when a hint exists (is non-nil).

**3. Slide image display**

```swift
if let nsImage = viewModel.currentNSImage {
    Image(nsImage: nsImage)
        .resizable()
        .scaledToFit()
} else {
    Color.black
}
```

If the image has been loaded, display it; if it is still loading (`nil`), show black as a fallback.

### What Happens Without It

Using an Optional without `if let` can lead to crashes when the value is `nil`. Force unwrapping (`!`) should be avoided; `if let` is the safe approach.

---

## 9. `.task { }` — Async Task Modifier

### What It Is

`.task { }` is a modifier that **starts an asynchronous operation when the view appears** and **automatically cancels it when the view disappears**.

`async/await` is Swift's mechanism for asynchronous processing. An operation marked with `await` means "wait for completion without blocking the thread."

### Why It Is Used Here

```swift
.task {
    await viewModel.loadCurrentImage()   // Load the image asynchronously
    viewModel.play()                     // Start playback after loading completes
}
```

This is initialization logic that loads an image and starts playback when the slideshow appears. Because of `await`, this can only be called inside `.task { }`.

### Difference from `onAppear`

```swift
// BAD example (also prohibited by architecture rules)
.onAppear {
    Task { await viewModel.loadCurrentImage() }  // Not cancelled when the view disappears
}

// Recommended
.task {
    await viewModel.loadCurrentImage()           // Automatically cancelled when the view disappears
}
```

`.task { }` is cancelled in sync with the view's lifecycle, which **prevents memory leaks and unnecessary processing**.

---

## 10. `.onKeyPress()` — Keyboard Events

### What It Is

`.onKeyPress(_:)` is a modifier that registers a handler for when a specific key is pressed. It is used in combination with `.focusable()`, which allows a view to receive keyboard focus.

The `.handled` return value means "this key input has been processed (do not propagate further)."

### Why It Is Used Here

```swift
.focusable()
.onKeyPress(.space) {
    if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
    return .handled   // Override the default behavior of the space key
}
.onKeyPress(.leftArrow) {
    Task { await viewModel.previous() }
    return .handled
}
.onKeyPress(.rightArrow) {
    Task { await viewModel.userDidNext() }
    return .handled
}
```

This enables keyboard controls for the slideshow. Space toggles play/pause, and arrow keys navigate between slides.

### What Happens Without It

The slideshow could only be controlled by mouse or touch, significantly degrading the experience for keyboard users.

---

## 11. `.onTapGesture` / `.simultaneousGesture` / `DragGesture` — Gestures

### What It Is

- `.onTapGesture { }` -- Detects a tap (click)
- `DragGesture` -- Detects a drag operation
- `.simultaneousGesture(_:)` -- Recognizes a gesture **simultaneously** with other gestures

### Why It Is Used Here

**Tap**:

```swift
.onTapGesture {
    viewModel.userDidInteract()   // A tap shows the filmstrip
}
```

Tapping the screen displays the filmstrip (the control UI).

**Drag (Swipe)**:

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 20)
        .onEnded { value in
            let dx = value.translation.width   // Horizontal displacement
            let dy = value.translation.height  // Vertical displacement
            if abs(dx) > abs(dy) {
                if dx < -50 {
                    Task { await viewModel.userDidNext() }    // Swipe left -> next
                } else if dx > 50 {
                    Task { await viewModel.previous() }      // Swipe right -> previous
                }
            } else {
                viewModel.userDidInteract()   // Vertical swipe -> treat as interaction
            }
        }
)
```

`minimumDistance: 20` means "consider it a drag only after moving 20 points or more." This prevents accidental taps from being interpreted as drags.

`.simultaneousGesture(_:)` is used so that the drag is recognized **simultaneously** with `.onTapGesture`. Normally, SwiftUI picks only one gesture when multiple gestures conflict, but `.simultaneousGesture` lets both operate independently.

### What Happens If You Use `.gesture` Instead of `.simultaneousGesture`

Tap and drag would conflict, and only one of them would be recognized.

---

## 12. `.animation()` — Animation

### What It Is

`.animation(_:value:)` is a modifier that applies an animation when the specified value changes. When the value changes, SwiftUI renders that change as a smooth motion.

### Why It Is Used Here

```swift
.animation(.easeInOut(duration: 0.5), value: viewModel.currentIndex)
.animation(.easeInOut(duration: 0.3), value: viewModel.showFilmstrip)
.animation(.easeInOut(duration: 0.5), value: viewModel.fullscreenHint)
```

Animations are configured for each of the three values:

- `currentIndex` changes -> Slide transition animation (0.5 seconds)
- `showFilmstrip` changes -> Filmstrip show/hide animation (0.3 seconds)
- `fullscreenHint` changes -> Hint display fade animation (0.5 seconds)

`.easeInOut` is a natural animation curve that starts slow, speeds up in the middle, and slows down at the end.

### What Happens Without It

The screen would snap instantly when values change, making it difficult for users to understand what happened.

---

## 13. `.transition()` — Transition

### What It Is

`.transition(_:)` specifies the animation for the **moment a view appears or disappears**. While `.animation()` animates "value changes," `.transition()` is specifically for "view insertion and removal."

### Why It Is Used Here

```swift
slideImage
    .transition(slideTransition)   // Transition when switching slides
```

```swift
FilmstripView(...)
    .transition(.move(edge: .bottom).combined(with: .opacity))
    // Slides up from the bottom while fading in; slides down while fading out
```

```swift
if let hint = viewModel.fullscreenHint {
    fullscreenHintOverlay(hint)
        .transition(.opacity)   // Fade in / fade out
}
```

`.combined(with:)` combines multiple transitions. Here it applies "movement + opacity change" simultaneously.

### What Happens Without It

Views would appear and disappear instantly. Each time a view is swapped via an `if` condition, the display would look jarring.

---

## 14. `@ViewBuilder` — View Builder Attribute

### What It Is

`@ViewBuilder` is an attribute indicating that "views can be built inside this function or property." It enables the use of `if/else` and `switch` to return views.

### Why It Is Used Here

In this file, two properties/methods are annotated with `@ViewBuilder`.

```swift
@ViewBuilder
private func fullscreenHintOverlay(_ hint: SlideshowPlayerViewModel.FullscreenHintType) -> some View {
    let label: String = switch hint {   // Switch label based on hint value
    case .enter: "Full Screen: Fn+F"
    case .exit: "Exit Full Screen: Esc"
    }
    // ...
    Label(label, systemImage: icon)
        .font(.callout)
        // ...
}
```

```swift
@ViewBuilder
private var slideImage: some View {
    if let nsImage = viewModel.currentNSImage {   // Returns views via conditional branching
        Image(nsImage: nsImage)
    } else {
        Color.black
    }
}
```

`slideImage` returns different view types (`Image` or `Color`) through `if/else`. Without `@ViewBuilder`, the return types would not match, causing a compile error.

### What Happens Without It

You would not be able to return `some View` from functions that contain conditional branching. You would need to rewrite using ternary operators `? :` or other approaches, adding complexity.

---

## 15. `AnyTransition` — Type-Erased Transition

### What It Is

SwiftUI transitions such as `.opacity`, `.move(edge:)`, and `.slide` each have different types. `AnyTransition` is a type that **erases** these types so they can be handled uniformly.

### Why It Is Used Here

```swift
private var slideTransition: AnyTransition {
    switch viewModel.slideshow.config.transition {
    case .none:
        return .identity          // AnyTransition.identity
    case .fade, .dissolve:
        return .opacity           // AnyTransition.opacity
    case .slide:
        return .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }
}
```

To **return different transitions from a `switch` statement**, the return type must be unified. The static members `.identity`, `.opacity`, and `.asymmetric(...)` all return `AnyTransition`, which is why it works as the computed property's return type. Without `AnyTransition`, Swift would require each branch to return the exact same concrete type.

`.asymmetric` is a special transition that allows you to set different transitions for insertion and removal. It creates the "slide forward" effect where a slide enters from the right and exits to the left.

### What Happens Without `AnyTransition`

If the computed property declared a more specific return type, Swift would require all branches to return the same concrete type. `AnyTransition` serves as the common return type that unifies all transition variants.

---

## 16. `.onReceive(NotificationCenter...)` — Observing Notifications

### What It Is

**NotificationCenter** is a mechanism that broadcasts "something happened" events across the entire app. `.onReceive(_:)` is a modifier that executes code when a specific notification arrives.

### Why It Is Used Here

```swift
.onReceive(
    NotificationCenter.default.publisher(
        for: NSWindow.didEnterFullScreenNotification
    )
) { _ in
    viewModel.windowDidEnterFullScreen()
}
```

On macOS, when a window enters full screen, the system sends `NSWindow.didEnterFullScreenNotification`. This code receives that notification and forwards it to the ViewModel.

`NotificationCenter.default.publisher(for:)` is a Combine framework Publisher that acts as an adapter to treat notifications as an asynchronous stream.

### What Happens Without It

You would be unable to detect fullscreen state changes, and features like hint display would stop working.

---

## 17. `.onHover` — Hover Events

### What It Is

`.onHover { hovering in ... }` is a modifier that executes code when the mouse cursor **enters or leaves** a view. When `hovering` is `true`, the cursor is over the view; when `false`, it has left.

### Why It Is Used Here

This file has `.onHover` in three places.

```swift
// Hover on the filmstrip
FilmstripView(...)
    .onHover { hovering in
        if hovering { viewModel.overlayHoverBegan() }
        else { viewModel.overlayHoverEnded() }
    }

// Hover on the button group
HStack { ... }
    .onHover { hovering in
        if hovering { viewModel.overlayHoverBegan() }
        else { viewModel.overlayHoverEnded() }
    }

// Hover on the entire screen
.onHover { hovering in
    if hovering { viewModel.userDidInteract() }
}
```

When the cursor is over the control UI (filmstrip, buttons), the auto-hide timer is paused; when the cursor leaves, the timer resumes.

### What Happens Without It

The UI would auto-hide even while the user is interacting with the filmstrip, making it difficult to use.

---

## 18. `Task { await ... }` — Async Calls Inside Closures

### What It Is

`async` functions can only be called from an `async` context (such as an `async` function or a `.task { }` modifier). Regular closures (e.g., a button's `action:`) are synchronous, so `await` cannot be used directly in them.

`Task { await ... }` is the syntax for "create a new async task and use `await` inside it."

### Why It Is Used Here

```swift
onSelect: { index in Task { await viewModel.jumpTo(index: index) } },
onNext: { Task { await viewModel.userDidNext() } },
```

`onSelect` and `onNext` are received as synchronous closures. However, `viewModel.jumpTo(index:)` is an `async` function. Wrapping it in `Task { }` allows launching asynchronous work from a synchronous closure.

### When to Use `.task { }` vs `Task { await ... }`

| Situation | What to Use |
|-----------|-------------|
| Initialization when a view appears | `.task { }` |
| Async calls from event handlers like button presses | `Task { await ... }` |

`.task { }` is automatically cancelled when the view disappears, but `Task { }` is not. For short-lived operations (like moving to the next slide), `Task { }` is appropriate.

---

## 19. `.id()` — Unique View Identity

### What It Is

`.id(_:)` assigns a unique identifier to a view. SwiftUI reuses views with the same ID as "the same view" and recreates views whose ID has changed as "a different view."

### Why It Is Used Here

```swift
slideImage
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .id(viewModel.currentIndex)   // <- Uses the current slide number as the ID
    .transition(slideTransition)
```

When `currentIndex` changes (= the slide switches), SwiftUI recognizes that "the old view disappeared and a new view appeared." This triggers the `.transition()`.

Without `.id()`, SwiftUI would try to reuse the view, so no "insertion/removal" would occur and the `.transition()` animation would not fire.

### What Happens Without It

The slide transition animation (`.transition(slideTransition)`) would not work, and images would swap without animation.

---

## 20. Pitfalls Learned in Practice

Here are pitfalls encountered during actual development related to this file.

### Pitfall 1: Choosing Between `.task {}` and `Task {}`

Creating a `Task {}` inside `.onAppear` means **the task is not cancelled when the View disappears**. The task continues running after navigation, potentially writing to a ViewModel that no longer exists.

```swift
// BAD -- The task keeps running even after the View disappears
.onAppear {
    Task { await viewModel.loadCurrentImage() }
}
```

Using the `.task { }` modifier ensures the task is **automatically cancelled** when the View is hidden. If you want to re-run the task when a value changes, use `.task(id:)`.

```swift
// GOOD -- Automatically cancelled when the View disappears
.task {
    await viewModel.loadCurrentImage()
    viewModel.play()
}

// GOOD -- Cancels the previous task and re-runs whenever currentIndex changes
.task(id: viewModel.currentIndex) {
    await viewModel.loadCurrentImage()
}
```

**Guidelines for choosing**:
| Situation | What to Use |
|-----------|-------------|
| Loading data when a View appears | `.task { }` |
| Re-running whenever a value changes | `.task(id: value) { }` |
| Short-lived operations like button presses | `Task { await ... }` |
| Work unrelated to the View lifecycle (e.g., sending logs) | `Task { }` |

**Note**: `.task` cancellation is **cooperative**. Unless the async work checks `Task.isCancelled` or uses cancellation-aware APIs (like `Task.sleep`), the work will not actually stop.

---

### Pitfall 2: Square Thumbnails Breaking in LazyVGrid

When trying to display thumbnails as squares in a filmstrip or similar layout, there are two common mistakes.

```swift
// BAD (1) -- scaledToFill causes the image's layout size to exceed the frame,
//            breaking hit testing on overlapping buttons
Image(nsImage: nsImage)
    .resizable()
    .scaledToFill()
    .frame(width: 80, height: 80)

// BAD (2) -- LazyVGrid proposes infinite height,
//            so .fill does not produce a square
Image(nsImage: nsImage)
    .resizable()
    .aspectRatio(1, contentMode: .fill)
```

The correct approach is to **first fix the width, then use `aspectRatio(1, contentMode: .fit)` to make height equal to width**.

```swift
// GOOD -- Fix the width first, then use aspect ratio to make it square
ZStack {
    Color.gray.opacity(0.15)           // Letterbox background
    if let nsImage = image {
        Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()             // Fits within the frame
    }
}
.frame(maxWidth: .infinity)            // Expand to fill the column width
.aspectRatio(1, contentMode: .fit)     // height = width -> square
.clipShape(RoundedRectangle(cornerRadius: 6))
```

**Key point**: `scaledToFill()` causes the layout size to overflow, which can make buttons layered on top untappable. The combination of `scaledToFit()` plus a letterbox background is the safe approach.

---

### Pitfall 3: Coordinating Actions Between Sibling Views

Consider a scenario like "when the edit button in the library panel is pressed, check if the creation form has unsaved data." It is tempting to have sibling views communicate directly, but **having sibling views access each other's ViewModels is an anti-pattern**.

```swift
// BAD -- A sibling view directly references another sibling's ViewModel
struct SlideshowLibraryPanel: View {
    let createViewModel: CreateSlideshowViewModel  // <- A ViewModel belonging to another sibling
    func onEditTapped() {
        if createViewModel.hasUnsavedWork { ... }  // <- Blurred responsibilities
    }
}
```

The correct approach is to **use the parent view as a coordinator, connecting siblings via closures**.

```swift
// GOOD -- The parent view (HomeView) acts as coordinator
struct HomeView: View {
    let createViewModel: CreateSlideshowViewModel

    var body: some View {
        HStack {
            SlideshowLibraryPanel(
                onEdit: { slideshow in handleEdit(slideshow) }  // Notify via closure
            )
            LibraryPickerView(viewModel: createViewModel)
        }
    }

    private func handleEdit(_ slideshow: SlideshowResponse) {
        if createViewModel.hasUnsavedWork {
            pendingEditSlideshow = slideshow   // Show a confirmation dialog
        } else {
            applyEdit(slideshow)              // Apply directly
        }
    }
}
```

**Why the parent view**: The parent view holds the ViewModels for both sibling views, making it the natural place for guard logic ("is there unsaved work?"). The sibling views simply notify the parent via closures that "something happened," without needing to know about each other.

---

## 21. What You Can Learn from This File — Summary

| Concept | What You Learn |
|---------|----------------|
| `struct ... : View` | SwiftUI UI components are built through protocol conformance |
| `let` vs `var` | Express intent through the type system (immutable vs. mutable) |
| `@escaping` | Explicitly marks closures that outlive their scope |
| `some View` | Opaque types that hide complex type details |
| `ZStack` / `HStack` | Layering and horizontal arrangement of views |
| `.ignoresSafeArea()` | Drawing beyond system UI to the screen edges |
| `.frame()` / `.padding()` | Declarative specification of size and spacing |
| `if let` | Safely unwrapping Optionals |
| `.task { }` | Async processing tied to the view lifecycle |
| `.onKeyPress()` | Implementing keyboard shortcuts |
| Gestures | Simultaneous recognition of tap and drag |
| `.animation()` | Turning value changes into smooth animations |
| `.transition()` | Animating view insertion and removal |
| `@ViewBuilder` | Writing functions that return views with conditional branching |
| `AnyTransition` | Type erasure for handling different transition types uniformly |
| `.onReceive` | Receiving system notifications in views |
| `.onHover` | Detecting mouse cursor hover (macOS) |
| `Task { await }` | Launching async work from synchronous closures |
| `.id()` | Controlling view identity to trigger transitions |

### Patterns Visible Across the Whole File

1. **Declarative UI**: In SwiftUI, you declare "what it should look like" and leave "when to update" to the framework. `.animation(value:)` and `.id()` are both quintessential examples of this declarative approach.

2. **Modifier Chaining**: Connecting `.frame()`, `.padding()`, `.transition()`, `.onTapGesture()`, and others with dots is the SwiftUI way. Code reads best when ordered "back to front on screen" or "primary logic to auxiliary logic."

3. **Lifecycle Awareness**: Just like the distinction between `.task { }` and `Task { }`, it is critical in Swift/SwiftUI to always be conscious of when processing starts and when it ends.
