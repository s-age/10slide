# Swift Concurrency Practical Guide — Avoiding Failures with Swift 6 Concurrency

**Category:** Advanced (Cross-Topic Guide)

In Swift 6, **Strict Concurrency** checking is enabled by default. The compiler rejects code that could cause data races as build errors, which means many conventional coding patterns no longer compile.

This guide compiles the problems actually encountered in the 10slide codebase and their resolution patterns.

---

## Overview

There are three core concepts in Swift Concurrency.

| Concept | One-line explanation |
|---------|---------------------|
| **Sendable** | A promise to the compiler that "this type can be safely passed between threads" |
| **Actor** | A mechanism that protects internal state so only one task can access it at a time |
| **async/await** | Syntax for writing asynchronous operations linearly without callbacks |

In Swift 6, **code that does not combine these correctly will not build**. Let's look at each pattern below.

---

## 1. What Sendable Is and Why It Is Required in Swift 6

### What is this?

`Sendable` is a protocol that tells the compiler "this value can be safely passed across threads (actors)." In Swift 6, values that cross actor boundaries must, in principle, be `Sendable`.

### Why does it matter?

The most dangerous bug in concurrent programs is a **data race**. When two threads simultaneously read from and write to the same data, crashes or corrupted data result. `Sendable` is the mechanism the compiler uses to verify that "this type is safe."

### Sendable support by type

| Type | Can be Sendable? | Condition |
|------|-----------------|-----------|
| `struct` | Automatic conformance | If all properties are `Sendable` |
| `enum` | Automatic conformance | If all associated values are `Sendable` |
| `final class` | Manual conformance | If all properties are `let` and `Sendable` |
| Non-final `class` | Not possible | Subclasses could add mutable state |
| `actor` | Always `Sendable` | Actors have built-in protection |

### Correct examples

```swift
// ✅ struct — automatically Sendable if all properties are Sendable
struct SlideDTO: Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
}
```

```swift
// ✅ final class — Sendable with let-only properties
final class PresentationContainer: Sendable {
    private let createSlideshow: any CreateSlideshowUseCaseProtocol  // Sendable protocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol
}
```

### Incorrect examples

```swift
// ❌ Non-final class cannot be Sendable
class UseCaseRequest: Sendable {  // Compile error
    func validate() throws { }
}
```

```swift
// ❌ final class with var cannot be Sendable
final class Cache: Sendable {
    var items: [String: Data] = [:]  // Compile error: var is incompatible with Sendable
}
```

```swift
// ❌ Silencing warnings with @unchecked Sendable (prohibited in this project)
final class Cache: @unchecked Sendable {
    var items: [String: Data] = [:]  // Compiles, but hides data race risks
}
```

### Real-world example in 10slide

UseCase Request types were originally designed using `class` inheritance, but this caused compile errors in Swift 6 because they could not be made `Sendable`. The solution was to switch to `protocol UseCaseRequest: Sendable` + `struct`.

```swift
// ✅ protocol + struct pattern (current design)
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let slides: [SlideInfo]
    func validate() throws { /* ... */ }
}
```

---

## 2. @MainActor and Async Method Pitfalls — The Index Snapshot Pattern

### What is this?

`@MainActor` is an annotation marking that "this type or method runs only on the main thread." SwiftUI ViewModels are typically isolated with `@MainActor`.

### Problem: Stale writes in async methods

Even in a `@MainActor` method, the **main thread is temporarily released** at every `await` point. If another operation (such as navigating to the next slide) interleaves during that time, an old result can overwrite a newer one.

SwiftUI's `.task(id:)` modifier automatically cancels the previous task when `id` changes, but this automatic cancellation is lost when the logic is moved into a ViewModel method.

### Incorrect example

```swift
// ❌ If the index changes during await, an old image overwrites the current one
@MainActor
func loadCurrentImage() async {
    guard let slide = currentSlide else { return }
    do {
        let data = try await loadSlideImageUseCase.execute(slide: slide)
        // ⚠️ currentIndex may have changed by this point
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        // ⚠️ currentIndex may have changed here too
        currentNSImage = image  // Overwrites with a stale image!
    } catch {
        currentNSImage = nil
    }
}
```

### Correct example: Index snapshot pattern

```swift
// ✅ Snapshot the index before await, then verify after every await
@MainActor
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex  // ① Take a snapshot

    do {
        let data = try await loadSlideImageUseCase.execute(slide: slide)
        guard currentIndex == expectedIndex else { return }  // ② Guard after fetch

        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        guard currentIndex == expectedIndex else { return }  // ③ Guard after decode too

        currentNSImage = image
    } catch {
        currentNSImage = nil
    }
}
```

### Rules

- **Before** `await`, copy the index or ID to a local variable (snapshot)
- **After** every `await`, add a guard condition
- Be aware that moving `.task(id:)` logic into a ViewModel method loses automatic cancellation

---

## 3. Correct Usage of Task.detached — Offloading CPU-Heavy Work from the Main Thread

### What is this?

`Task.detached` creates a new task **completely detached from the calling actor**. When used inside a `@MainActor` method, the closure runs on a background thread rather than the main thread.

### Why is it necessary?

Image decoding (`NSImage(data:)`) and file I/O (`Data(contentsOf:)`) block the CPU for extended periods. Running these on the main thread causes the UI to stutter (frame drops).

### Correct examples

```swift
// ✅ Run file I/O on a background thread
func load() async throws -> ConfigDTO {
    let fileURL = self.fileURL  // Copy Sendable value to local
    return try await Task.detached(priority: .utility) {
        let data = try Data(contentsOf: fileURL)
        return try YAMLDecoder().decode(ConfigDTO.self, from: data)
    }.value
}
```

```swift
// ✅ Run image decoding on a background thread (with injected decoder)
private let imageDecoder: @Sendable (Data) -> NSImage?

func loadCurrentImage() async {
    let data = try await loadSlideImageUseCase.execute(...)
    let decode = imageDecoder  // Copy to local (Sendable)
    currentImage = await Task.detached(priority: .userInitiated) {
        decode(data)
    }.value
}
```

### Incorrect examples

```swift
// ❌ Decoding images directly in a @MainActor method — UI stutters
@MainActor
func loadCurrentImage() async {
    let data = try await loadSlideImageUseCase.execute(...)
    currentImage = NSImage(data: data)  // Heavy work on the main thread
}
```

```swift
// ❌ Capturing self in Task.detached when self is not Sendable
Task.detached {
    let data = try Data(contentsOf: self.fileURL)  // Compile error
}
```

### Choosing the right priority

| Type of work | priority |
|-------------|----------|
| Image loading directly tied to user action | `.userInitiated` |
| Background file I/O | `.utility` |
| Thumbnail prefetching | `.background` |

### Testing technique: Inject the decoder

Calling `NSImage(data:)` in tests requires actual image data. By injecting the decoder as a `@Sendable` closure via `init`, you can substitute a stub in tests.

```swift
// Production code
init(..., imageDecoder: @Sendable @escaping (Data) -> NSImage? = { NSImage(data: $0) }) {
    self.imageDecoder = imageDecoder
}

// Test code
sut = SlideshowPlayerViewModel(
    ...,
    imageDecoder: { _ in NSImage(size: .init(width: 1, height: 1)) }
)
```

---

## 4. The @ModelActor Pattern — Handling SwiftData in a Thread-Safe Way

### What is this?

`@ModelActor` is a macro provided by SwiftData that auto-generates `modelContext` and `modelExecutor` on the annotated `actor`. All data operations execute on that actor's thread, guaranteeing thread safety.

### Why is an actor necessary?

`ModelContext` is **not thread-safe**. Accessing it from a different thread can cause relationship lazy loading to trigger crashes or data corruption. `Mutex<ModelContext>` serializes access but **does not guarantee execution on the same thread**, so the problem remains.

### Correct example

```swift
// ✅ @ModelActor pins all access to the same thread
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    // modelContext and modelExecutor are auto-generated by the macro

    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))  // Convert to DTO inside the actor before returning
    }

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        SlideshowDTO(id: model.id, name: model.name, slides: model.slides.map { ... })
    }
}
```

### Incorrect examples

```swift
// ❌ Mutex<ModelContext> — thread is not pinned
final class SlideshowDataSource: Sendable {
    private let context: Mutex<ModelContext>

    func fetchAll() throws -> [SlideshowDTO] {
        context.withLock { ctx in  // May execute on a different thread each time
            try ctx.fetch(FetchDescriptor<SlideshowModel>())  // Lazy loading causes corruption
        }
    }
}
```

```swift
// ❌ Returning @Model from outside the actor
@ModelActor
actor SlideshowDataSource {
    func fetchAll() throws -> [SlideshowModel] {  // @Model is not Sendable!
        try modelContext.fetch(FetchDescriptor<SlideshowModel>())
    }
}
```

### Rules

- Declare as `@ModelActor actor` (not `final class`)
- `init(modelContainer:)` is generated by the macro — do not write it yourself
- Never let `@Model` objects escape the actor — always convert to DTO before returning
- Declare protocols with `async throws` (actor methods automatically become async)

---

## 5. Protecting State with Mutex<T>

### What is this?

`Mutex<T>`, included in Swift 6's `Synchronization` module, protects access to its wrapped value with a lock. It allows `final class` types to be correctly made `Sendable` without `@unchecked Sendable`.

### When to use it?

- When you need to read and write the same value from multiple actors or threads
- However, it is unnecessary when `@ModelActor` (for SwiftData) or `@MainActor` is sufficient

### Correct example

```swift
// ✅ Protect a cache with Mutex
import Synchronization

final class ImageCache: Sendable {
    private let storage: Mutex<[String: Data]> = Mutex([:])

    func store(_ data: Data, for key: String) {
        storage.withLock { $0[key] = data }
    }

    func retrieve(for key: String) -> Data? {
        storage.withLock { $0[key] }
    }
}
```

### Incorrect examples

```swift
// ❌ Calling await inside withLock — compile error
storage.withLock { cache in
    let data = try await fetchData()  // await cannot be used inside withLock
    cache[key] = data
}
```

```swift
// ❌ Mutex is unnecessary for values used only with @MainActor
@MainActor
final class ViewModel {
    private let count: Mutex<Int> = Mutex(0)  // Overkill — @MainActor is sufficient
}
```

```swift
// ❌ Mutex is unnecessary for values that never change after init
final class Config: Sendable {
    private let settings: Mutex<[String: String]>  // Overkill — let is sufficient
    init(settings: [String: String]) {
        self.settings = Mutex(settings)  // If it never changes, a let property is fine
    }
}
```

### Mutex vs actor: choosing the right tool

| Characteristic | `Mutex<T>` | `actor` |
|---------------|-----------|---------|
| Access | Synchronous (`withLock`) | Asynchronous (`await`) |
| Can use `await` inside? | No | Yes |
| Primary use case | Simple caches, counters | Data sources, complex state management |

---

## 6. Practical Patterns for Making DI Containers and Request Types Sendable

### Making DI containers Sendable

When passing a DI container's method reference as a `@Sendable` closure, the container itself must be `Sendable` or a compile error results.

```
warning: converting non-Sendable function value to
'@MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel' may introduce data races
```

### Correct example

```swift
// ✅ final class + let-only properties → Sendable
final class PresentationContainer: Sendable {
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol

    init(createSlideshow: any CreateSlideshowUseCaseProtocol,
         loadSlideImage: any LoadSlideImageUseCaseProtocol) {
        self.createSlideshow = createSlideshow
        self.loadSlideImage = loadSlideImage
    }

    func makeSlideshowPlayerViewModel(slideshow: Slideshow) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(slideshow: slideshow, loadSlideImage: loadSlideImage)
    }
}
```

### Incorrect examples

```swift
// ❌ Having var causes a compile error
final class PresentationContainer: Sendable {
    var loadSlideImage: any LoadSlideImageUseCaseProtocol  // var is incompatible with Sendable
}
```

```swift
// ❌ Passing a method reference from a non-Sendable container
class PresentationContainer {  // Not Sendable
    func makePlayer(slideshow: Slideshow) -> SlideshowPlayerViewModel { ... }
}

// In ContentView
ContentView(makePlayer: container.makePlayer)  // ⚠️ non-Sendable function value
```

### Making Request types Sendable

Requests passed to UseCases cross actor boundaries and therefore require `Sendable`.

```swift
// ✅ protocol + struct — automatically Sendable
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String      // String is Sendable
    let slides: [SlideInfo]  // OK if SlideInfo is Sendable
    func validate() throws {
        guard !name.isEmpty else { throw ValidationError.emptyName }
    }
}
```

```swift
// ❌ class inheritance — cannot be Sendable
class UseCaseRequest {               // Non-final class cannot be Sendable
    func validate() throws { }
}
class CreateSlideshowRequest: UseCaseRequest {  // Subclass could add var
    let name: String
}
```

---

## Summary

| Pattern | When to use | Key point |
|---------|------------|-----------|
| `Sendable` struct/enum | Data types that cross actor boundaries | Automatic conformance if all properties are `Sendable` |
| `Sendable` final class | When a reference type is needed (e.g., DI containers) | `let` properties only, `@unchecked` is prohibited |
| Index snapshot | `@MainActor` async methods with multiple `await`s | Snapshot before `await`, guard after every `await` |
| `Task.detached` | CPU-heavy work (image decoding, I/O) | Capture only Sendable values, set priority appropriately |
| `@ModelActor` | SwiftData data sources | Never let `@Model` escape — convert to DTO before returning |
| `Mutex<T>` | Simple mutable state shared across multiple actors | Cannot use `await` inside `withLock`; unnecessary if `@MainActor` suffices |
| `protocol + struct` Request | UseCase input types | Use protocol instead of class inheritance to ensure `Sendable` |

### Principles

1. **Do not use `@unchecked Sendable`** — it only disables the compiler's protection while bugs remain hidden
2. **`await` is a suspension point** — always be aware that state may have changed before and after it
3. **Type choice determines safety** — the choice of `struct` / `final class` / `actor` directly dictates how easily `Sendable` conformance is achieved
