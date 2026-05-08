# TenSlideApp.swift — Swift Beginner's Guide

**Source file:** `Sources/App/TenSlideApp.swift`

## Role of This File

`TenSlideApp.swift` is the **front door of the app**. When macOS launches the app, this is the first file that gets executed. It initializes the DI (Dependency Injection) container and assembles the first window and its contents.

The entire code is only 28 lines, but it is packed with important Swift concepts. Let's read through it from top to bottom.

---

## Full Source Code

```swift
import SwiftUI
import SwiftData

@main
struct TenSlideApp: App {
    private let container: Container

    init() {
        do {
            container = try Container()
        } catch {
            fatalError("DI initialization failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                thumbnailViewModel: container.presentation.makeThumbnailViewModel(),
                createViewModel: container.presentation.makeCreateSlideshowViewModel(),
                makeSlideshowPlayerViewModel: container.presentation.makeSlideshowPlayerViewModel,
                makeSpritePlayerViewModel: container.presentation.makeSpritePlayerViewModel,
                makeSlideshowLibraryViewModel: container.presentation.makeSlideshowLibraryViewModel
            )
        }
        .modelContainer(container.infrastructure.modelContainer)
    }
}
```

---

## Concept 1 — `import SwiftUI` / `import SwiftData`: Importing Frameworks

### What Is This?

`import` is a statement that tells Swift to load an external library (framework). `SwiftUI` is Apple's UI-building framework, and `SwiftData` is a data persistence (saving/loading) framework.

### Why Is It Used Here?

- Without `SwiftUI`, types like `App` protocol, `WindowGroup`, and `Scene` are unavailable.
- Without `SwiftData`, the `.modelContainer()` modifier is unavailable.

### What If You Didn't Use It?

```swift
// If you omit import SwiftUI
struct TenSlideApp: App {  // ❌ Error: 'App' cannot be found
```

The compiler doesn't know what `App` is, so it produces a build error.

### Relevant Code

```swift
import SwiftUI
import SwiftData
```

---

## Concept 2 — `@main`: The App's Entry Point

### What Is This?

`@main` is a Swift **attribute** that tells the compiler "this file is the app's launch point." Every Swift program requires exactly one entry point, and `@main` serves that role.

### Why Is It Used Here?

A macOS app needs to know "where to begin execution" at launch time. When you add `@main`, Swift automatically calls that struct's `main()` function (provided by the `App` protocol). Developers don't need to write `main()` themselves -- just declaring it is enough.

### What If You Didn't Use It?

The entire project would lack an entry point, resulting in a linker error saying "entry point not found." Conversely, adding `@main` to two or more types also produces an error.

### Relevant Code

```swift
@main
struct TenSlideApp: App {
```

---

## Concept 3 — `struct TenSlideApp: App`: Structs and App Protocol Conformance

### What Is This?

**`struct` (structure)** is one of Swift's data types. It's similar to a class (`class`), but differs in that it's a value type (passed by copy).

**`: App`** represents conformance to a protocol. A protocol is a "contract" that says "please follow these rules." The `App` protocol requires "having a `body` property."

### Why Is It Used Here?

SwiftUI apps require a type that conforms to the `App` protocol. This is because Apple designed it so that "app definitions go through this protocol." A `struct` is used because the app configuration can be expressed as a lightweight value type (since the DI container holds the state, a struct is sufficient).

### What If You Didn't Use It?

```swift
// If you don't conform to the App protocol
@main
struct TenSlideApp {  // ❌ @main requires a static main() method
```

`@main` and the `App` protocol go together as a pair. Since `App` provides the implementation of `main()`, not conforming to it results in a compile error.

### Relevant Code

```swift
struct TenSlideApp: App {
```

---

## Concept 4 — `private let container: Container`: Access Control and Constants

### What Is This?

- **`private`**: An access control modifier indicating that this property can only be accessed from within `TenSlideApp` itself.
- **`let`**: A constant that cannot be changed once a value is assigned (`var` is for mutable variables).
- **`container: Container`**: A property of type `Container` that holds the app-wide dependency injection (DI) container.

### Why Is It Used Here?

After `container` is initialized in `init()`, it never needs to be replaced during the app's operation. Using `let` prevents bugs where "someone accidentally overwrites it." Additionally, making it `private` encapsulates it so that external code cannot directly manipulate `container`.

### What If You Didn't Use It?

```swift
var container: Container  // Mutable and visible from outside
```

External code could write `app.container = anotherContainer` and replace it, causing unexpected behavior.

### Relevant Code

```swift
private let container: Container
```

---

## Concept 5 — `init()`: Initializer

### What Is This?

`init()` is an **initialization method**. It runs automatically when an instance of a struct or class is created (when `TenSlideApp()` is called). All `let` properties must have their values set within `init()`.

### Why Is It Used Here?

It's used to initialize `container`. Since `Container()` can throw an error (`throws`), it needs to be handled safely using `do-catch` inside `init()`. By Swift's rules, `let` properties must either be given an initial value at declaration or be set within `init()`.

### What If You Didn't Use It?

```swift
private let container: Container = Container()
// ❌ Container() throws, so it cannot be called directly here
```

Calling a `throws` function without `try` results in a compile error. By explicitly writing `init()`, we create a place where `do-catch` can be used.

### Relevant Code

```swift
init() {
    do {
        container = try Container()
    } catch {
        fatalError("DI initialization failed: \(error)")
    }
}
```

---

## Concept 6 — `do-catch` / `fatalError`: Error Handling

### What Is This?

**`do-catch`** is a syntax for safely executing operations that may produce errors.

- `do { }` block: Write operations that might throw errors
- `try`: Placed before functions that can throw errors
- `catch { }` block: Write what to do when an error occurs

**`fatalError()`** is a function that immediately terminates the program. It's used to indicate an unrecoverable state.

### Why Is It Used Here?

Initializing `Container()` can fail (e.g., a required file is not found). If the app continued running after a failure, `container` would remain uninitialized, leading to crashes or incorrect behavior. Here, the decision is "if initialization fails, don't launch the app."

`fatalError` is used because a DI container initialization failure means the app cannot function properly, and it's safer to terminate clearly rather than showing users a half-broken state.

### What If You Wrote It Without `do-catch`?

```swift
// Using try? (ignoring failure and returning nil)
container = try? Container()
// ❌ container becomes Optional<Container>,
//    which doesn't match the type, and failures go unnoticed
```

### About `\(error)` (String Interpolation)

`"\(error)"` is Swift's **string interpolation**. Writing an expression inside `\( )` embeds its value into the string.

```swift
let name = "Swift"
print("Hello, \(name)!")  // → "Hello, Swift!"
```

### Relevant Code

```swift
do {
    container = try Container()
} catch {
    fatalError("DI initialization failed: \(error)")
}
```

---

## Concept 7 — `var body: some Scene`: Properties, the Scene Protocol, and the `some` Keyword

### What Is This?

This single line contains three elements.

**`var body`**: A **computed property** — it has no stored value but is recalculated each time it is accessed. `var` is used because computed properties require `var` in Swift (they cannot be `let`). It's required because the `App` protocol demands "provide a `body` property."

**`Scene`**: A protocol representing an app's screen (such as window groups). Windows, menu bars, and similar elements in macOS apps are types of `Scene`.

**`some Scene`**: `some` is a Swift feature called an **opaque type**. It means "returns some specific type that conforms to the `Scene` protocol."

### Why Use `some`?

The actual type returned by `body` is a complex type like `WindowGroup<ContentView>`. Writing this out precisely every time is tedious, and changing the implementation would require changing the type annotation too. Writing `some Scene` lets you declare just "returns something conforming to Scene," and the compiler infers the concrete type.

### What If You Wrote It Without `some`?

```swift
// Without some
var body: Scene { ... }
// ❌ To use protocol type 'any Scene' as a return type,
//    you need to write 'any Scene' (Swift 5.7+)
```

Also, using `any Scene` causes type erasure, making it harder for the compiler to optimize. `some` is superior in both performance and type safety.

### Relevant Code

```swift
var body: some Scene {
```

---

## Concept 8 — `WindowGroup { }`: Window Definition and Trailing Closures

### What Is This?

**`WindowGroup`** is a SwiftUI type that defines a window for macOS/iOS apps. The View written inside `{ }` becomes the window's content.

The `{ }` syntax is **syntactic sugar** called a **trailing closure**. When the last argument of a function is a closure (a function-type parameter), it can be written outside the parentheses with `{ }`.

```swift
// Original syntax
WindowGroup(content: { ContentView(...) })

// Trailing closure (same meaning)
WindowGroup {
    ContentView(...)
}
```

### Why Is It Used Here?

SwiftUI's UI is written "declaratively." `WindowGroup { ContentView(...) }` is simply declaring "the content of this window group is ContentView" -- when and how the window is displayed is managed by the SwiftUI framework.

### Relevant Code

```swift
WindowGroup {
    ContentView(
        thumbnailViewModel: container.presentation.makeThumbnailViewModel(),
        createViewModel: container.presentation.makeCreateSlideshowViewModel(),
        makeSlideshowPlayerViewModel: container.presentation.makeSlideshowPlayerViewModel,
        makeSpritePlayerViewModel: container.presentation.makeSpritePlayerViewModel,
        makeSlideshowLibraryViewModel: container.presentation.makeSlideshowLibraryViewModel
    )
}
```

Pay attention to the arguments of `ContentView(...)`. By calling `container.presentation.make*ViewModel()`, we retrieve ViewModels from the DI container and pass them in. This is dependency injection (DI) in practice. Instead of the View creating its own ViewModel, it receives one from outside, making testing and substitution easier.

---

## Concept 9 — `.modelContainer()`: Modifiers and SwiftData

### What Is This?

**Modifiers** are function calls chained onto SwiftUI Views or Scenes using a dot (`.`). They look like "property settings," but they're actually functions that return a new Scene/View.

**`.modelContainer()`** is a SwiftData modifier that injects a data store (ModelContainer) into the SwiftUI environment. Once set here, all child Views can perform database operations via `@Environment(\.modelContext)`.

### Why Is It Used Here?

By registering SwiftData's model container at the top-level Scene, all Views within the app can access the data. The `container.infrastructure.modelContainer` passed here is a ModelContainer instance managed by the DI container's Infrastructure layer.

### What If `.modelContainer()` Were Missing?

```swift
// If you omit .modelContainer()
WindowGroup { ContentView(...) }
// → When child Views try to use @Query or @Environment(\.modelContext),
//   a runtime error occurs (model container not configured)
```

### Modifiers Can Be Chained

```swift
WindowGroup { ... }
    .modelContainer(...)
    .commands { ... }  // You can add additional modifiers as well
```

### Relevant Code

```swift
.modelContainer(container.infrastructure.modelContainer)
```

---

## Pitfalls Learned in Practice

These are important points discovered during this project's development that you should know about when developing SwiftUI apps for macOS.

---

### Pitfall 1: `.navigationTitle()` Becomes the Window Title on macOS

#### What Happens

On macOS, when you add `.navigationTitle()` to the root view inside a `WindowGroup`, the string is displayed in the **window's title bar**. This works even without a `NavigationStack` or `NavigationSplitView`.

This behavior is hard to notice if you only have iOS development experience. On iOS, `.navigationTitle()` only appears in the navigation bar, and there is no concept of a window title.

#### Correct Approach

```swift
// ✅ Control the window title with .navigationTitle() (NavigationStack is not required)
var body: some Scene {
    WindowGroup {
        if let slideshow = currentSlideshow {
            SlideshowPlayerView(slideshow: slideshow)
                .navigationTitle(slideshow.name)   // → Slideshow name appears in the title bar
        } else {
            HomeView()
                .navigationTitle("")               // → Hides the title bar text
        }
    }
}
```

By adding `.navigationTitle()` to each branch of the `if`/`else`, you can dynamically switch the window title based on the app's state.

#### What NOT to Do

```swift
// ❌ Trying to set the window title using NSViewRepresentable — overly complex
struct WindowTitleSetter: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title  // window may be nil depending on timing
        }
        return view
    }
    // ...
}
```

**Key takeaway**: In macOS SwiftUI, `.navigationTitle()` is the official way to set the window title. There is no need to directly manipulate `window?.title` via `NSViewRepresentable`.

---

## What You Can Learn from This File

| Concept | Keyword | Summary |
|---------|---------|---------|
| Framework loading | `import` | Makes external libraries available for use |
| Entry point | `@main` | An attribute that declares the app's launch point |
| Protocol conformance | `struct ... : App` | A declaration saying "this type follows these rules" |
| Access control and constants | `private let` | A property that is invisible from outside and cannot be modified |
| Initialization | `init()` | Processing that runs automatically when an instance is created |
| Error handling | `do-catch` / `try` / `fatalError` | Safely catch errors, and terminate if unrecoverable |
| Opaque types | `some Scene` | Returns "something that conforms to this protocol" |
| Window definition | `WindowGroup { }` | Declares the app's window and its contents |
| Modifiers | `.modelContainer()` | Chains SwiftUI/SwiftData functionality |

### Summary

This file is small, but it's packed with the fundamentals of Swift app development.

1. **`import`** loads the libraries
2. **`@main` + `App` protocol** defines the app's launch point
3. **`init()` + `do-catch`** safely handles initialization that can fail
4. **`some Scene` + `WindowGroup`** declaratively assembles the UI
5. **`.modelContainer()`** delivers the data layer to the entire app

Understanding this flow gives you the big picture of "how a SwiftUI app starts running."
