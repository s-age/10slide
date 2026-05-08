# Domain Entity Patterns and Swift Fundamentals

> Audience: People who are just starting to learn Swift and wonder "why is it written this way?" when reading code.

---

## Target Source Files and Overview

| File | Type Category | Role |
|---|---|---|
| `Sources/Domain/Entities/Slide.swift` | Entity | Represents a single slide that makes up a slideshow |
| `Sources/Domain/Entities/Slideshow.swift` | Entity | Represents an entire slideshow including a collection of slides and its settings |
| `Sources/Domain/Entities/SlideshowConfig.swift` | Value Object | Represents slideshow playback settings (duration, transition, loop) |
| `Sources/Domain/Entities/SlideDuration.swift` | Enum Variant Set | Represents slide display durations (5s, 10s, ... 60s, manual) |
| `Sources/Domain/Entities/TransitionType.swift` | Enum Variant Set | Represents the types of slide transition animations |

These files belong to the **Domain layer**. The Domain layer is where the app's business rules are expressed as pure Swift types. It depends on neither UI nor I/O -- it is, so to speak, the "heart of the app."

---

## Full Source Code (for reference)

### Slide.swift

```swift
import Foundation

struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String
    var order: Int
    var duration: TimeInterval
    var title: String?
}
```

### Slideshow.swift

```swift
import Foundation

struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig
    var createdAt: Date

    static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
        Slideshow(
            id: UUID(),
            name: name,
            slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
            config: config,
            createdAt: Date()
        )
    }

    func applying(config: SlideshowConfig) -> Slideshow {
        var updated = self
        updated.config = config
        return updated
    }

    func updating(name: String, localIdentifiers: [String]) -> Slideshow {
        var updated = self
        updated.name = name
        updated.slides = Slideshow.makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0)
        return updated
    }

    private static func makeSlides(from localIdentifiers: [String], duration: TimeInterval) -> [Slide] {
        localIdentifiers.enumerated().map { index, id in
            Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
        }
    }
}
```

### SlideshowConfig.swift

```swift
import Foundation

struct SlideshowConfig: Equatable, Sendable, Codable {
    var duration: SlideDuration
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(
        duration: .five,
        transition: .fade,
        loop: true
    )
}
```

### SlideDuration.swift

```swift
import Foundation

enum SlideDuration: String, Equatable, Sendable, CaseIterable, Codable {
    case five = "5"
    case ten = "10"
    case fifteen = "15"
    case thirty = "30"
    case sixty = "60"
    case manual

    var seconds: TimeInterval? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .thirty: return 30
        case .sixty: return 60
        case .manual: return nil
        }
    }
}
```

> **Note**: `SlideDuration.seconds` returns `TimeInterval?` (Optional). The `manual` case returns `nil` because manual mode has no fixed duration — the user advances slides manually. This is why code like `config.duration.seconds ?? 0` uses nil-coalescing and `guard let duration = config.duration.seconds else { return }` uses optional binding.

### TransitionType.swift

```swift
import Foundation

enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve

    static let `default` = TransitionType.fade
}
```

---

## Concept-by-Concept Explanation

---

### 1. `struct` vs `class` -- Value Types and Reference Types

#### Definition

Swift has two ways to define types.

- **`struct` (structure)**: A "value type." When assigned to a variable or passed to a method, a **copy** is created.
- **`class`**: A "reference type." Assigning to a variable merely creates a **reference** to the same instance. No copy is created.

#### Why It Is Used Here

`Slide`, `Slideshow`, and `SlideshowConfig` are all defined as `struct`. There are three reasons for making Domain layer entities `struct`:

1. **Predictability**: Because copies are created, accidents where "a change in one place unexpectedly affects another" cannot happen.
2. **Thread safety**: Since `struct` values are not shared, they are safe even when multiple threads access them simultaneously (this works in concert with `Sendable`, discussed later).
3. **Testability**: Since state cannot be changed from outside, behavior is purely determined by inputs and outputs.

#### What Would Happen with `class`

```swift
// ❌ With class, references are shared
class SlideClass {
    var order: Int
    init(order: Int) { self.order = order }
}

let a = SlideClass(order: 0)
let b = a          // Not a copy -- points to the same instance as a
b.order = 99
print(a.order)     // 99 ← a was changed too!
```

```swift
// ✅ With struct, a copy is made
struct SlideStruct {
    var order: Int
}

let a = SlideStruct(order: 0)
var b = a          // An independent copy is created
b.order = 99
print(a.order)     // 0 ← a is unaffected
```

#### Relevant Code

```swift
struct Slide: Identifiable, Equatable, Sendable { ... }
struct Slideshow: Identifiable, Equatable, Sendable { ... }
struct SlideshowConfig: Equatable, Sendable, Codable { ... }
```

---

### 2. `Identifiable` -- A Type with a Unique Identifier

#### Definition

`Identifiable` is a standard Apple protocol that declares "this object has a property called `id`."

```swift
// Conceptual definition from Apple's standard library
protocol Identifiable {
    associatedtype ID: Hashable
    var id: ID { get }
}
```

#### Why It Is Used Here

`Slide` and `Slideshow` conform to `Identifiable`. This enables:

- Passing them directly to SwiftUI's `List` or `ForEach` (the `id:` parameter can be omitted)
- Determining "is this slide the same as that slide?" using the `id`

#### What Would Happen Without `Identifiable`

```swift
// Without Identifiable
ForEach(slides, id: \.localIdentifier) { slide in ... }  // Must specify the id key path every time

// With Identifiable ✅
ForEach(slides) { slide in ... }  // id is self-evident, so it can be omitted
```

#### Relevant Code

```swift
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID   // ← The id property required by Identifiable
    ...
}
```

---

### 3. `Equatable` -- Equality Comparison

#### Definition

`Equatable` is a protocol that declares "this type can be compared with `==`." Conforming to it lets you write `a == b`.

If all properties of a `struct` are `Equatable`, the Swift compiler **auto-generates** the `==` implementation.

#### Why It Is Used Here

- **Testing**: You can verify "does the expected `Slide` equal the actual `Slide`?" with `XCTAssertEqual`.
- **Diff detection**: You can easily check "did the config change?" with `oldConfig == newConfig`.
- **SwiftUI optimization**: When a ViewModel holds `Equatable` values, SwiftUI can optimize by skipping re-rendering of unchanged view portions.

#### What Would Happen Without `Equatable`

```swift
// ❌ Without Equatable
// let a: Slide = ...
// let b: Slide = ...
// if a == b { ... }  // Compile error: cannot compare

// You would need to write comparison logic manually (tedious and error-prone)
func isEqual(_ a: Slide, _ b: Slide) -> Bool {
    a.id == b.id &&
    a.localIdentifier == b.localIdentifier &&
    a.order == b.order
    // ... must be updated every time a property is added
}
```

#### Relevant Code

```swift
struct Slide: Identifiable, Equatable, Sendable { ... }
//                          ^^^^^^^^^ Compiler auto-generates ==
```

---

### 4. `Sendable` -- Thread Safety

#### Definition

`Sendable` is a protocol that declares "values of this type can be safely passed between different threads (actors)." Starting with Swift 6, a compile error occurs when a type that is not `Sendable` is passed between threads.

#### Why It Is Used Here

Modern Swift apps make heavy use of asynchronous processing. For example, when "fetching images from the photo library while updating the UI," `Slide` values are passed between the background thread and the main thread. Declaring `Sendable` tells the compiler "this can be safely passed."

If all properties of a `struct` are `Sendable`, the compiler automatically verifies safety.

#### What Would Happen Without `Sendable`

```swift
// ❌ Without Sendable → May cause compile errors in Swift 6 async contexts
func fetchSlides() async -> [Slide] { ... }
// Errors such as "Sending 'result' risks causing data races"
```

#### Relevant Code

```swift
struct Slide: Identifiable, Equatable, Sendable { ... }
//                                     ^^^^^^^^ Safe for cross-thread transfer
```

---

### 5. `let` vs `var` -- Immutable and Mutable Fields

#### Definition

- **`let`**: Cannot be changed once a value is set (constant)
- **`var`**: Can be changed later (variable)

#### Why It Is Used Here

Looking closely at `Slide`'s fields, there is clear intention behind the choice:

```swift
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID           // ← let: The ID never changes after creation
    let localIdentifier: String  // ← let: The reference to the original photo never changes either
    var order: Int         // ← var: The slide's display order can be changed
    var duration: TimeInterval   // ← var: The display duration can be adjusted later
    var title: String?     // ← var: A title can be added later
}
```

If `id` were `var`, it would be possible to "assign a different ID to the same slide," destroying the meaning of identity. Making it `let` allows the compiler to prevent erroneous changes.

#### What Would Happen If Everything Were `var`

```swift
// ❌ If id were var
var slide = Slide(id: UUID(), localIdentifier: "abc", order: 0, duration: 5, title: nil)
slide.id = UUID()  // The ID can be overwritten! Data consistency is broken
```

#### Relevant Code

```swift
let id: UUID                 // Immutable -- guarantees entity identity
let localIdentifier: String  // Immutable -- guarantees the reference to the original photo
var order: Int               // Mutable -- display order can be edited
```

---

### 6. `UUID` -- Universally Unique Identifier

#### Definition

`UUID` (Universally Unique Identifier) is a random 128-bit value that is unique worldwide. It is included in the `Foundation` framework, and you can generate a new ID simply by writing `UUID()`.

Example: `550e8400-e29b-41d4-a716-446655440000`

#### Why It Is Used Here

A "unique number" is needed to distinguish slides and slideshows. Reasons for using UUID:

- **No collisions**: Unlike sequential numbers (1, 2, 3...), even when generated simultaneously on multiple devices, the probability of producing the same value is effectively zero.
- **Not guessable**: Sequential numbers like 1, 2, 3... are predictable, but UUIDs are random.
- **Compatible with external systems**: When exchanging data over databases or networks, there is no need to worry about ID collisions.

#### What Would Happen with Sequential Numbers

```swift
// ❌ Sequential numbers can collide when created simultaneously in multiple places
var nextId = 0
let slide1 = Slide(id: nextId, ...)  // id: 0
nextId += 1
let slide2 = Slide(id: nextId, ...)  // id: 1
// Operating on the same counter from different threads causes a data race
```

#### Relevant Code

```swift
let id: UUID
// ...
Slideshow(id: UUID(), ...)  // UUID() generates a new unique ID each time
```

---

### 7. `Optional` (`?`) -- A Type That Might Have a Value

#### Definition

`Optional` is a type that can represent "both the case where a value exists and the case where it does not (`nil`)." `String?` means "either a String or nil."

#### Why It Is Used Here

`title: String?` expresses that "a slide may or may not have a title." It is natural for a slide to have no title immediately after a photo is added.

By using Optional, the compiler enforces a check: "have you considered the possibility of nil?"

#### What Would Happen Without Optional

```swift
// ❌ Trying to represent "no title" without Optional
var title: String = ""   // Empty string = no title? But you can't distinguish between an empty title and "not set"
var title: String = "(none)"  // Put a display string? Domain knowledge of UI leaks into the Domain layer

// ✅ With Optional, the meaning is clear
var title: String?  // nil = title not set, "Hello" = title exists
```

On the usage side, you unwrap like this:

```swift
// Safe unwrapping with if let
if let title = slide.title {
    print("Title: \(title)")
} else {
    print("No title")
}

// Default value with ??
let displayTitle = slide.title ?? "Untitled"
```

#### Relevant Code

```swift
var title: String?   // ← The absence of a title is represented by nil
```

---

### 8. `enum` and `rawValue` -- Enumerations and Raw Values

#### Definition

An `enum` (enumeration) is a type that lets you "choose one from a fixed set of options." An `enum` with a `rawValue` can associate each case with a string or number.

#### Why It Is Used Here

`TransitionType` represents the types of slide transition animations. By giving it a `String` `rawValue`:

1. In code, you can use readable names like `case fade`
2. For storage and communication, it can be treated as the string `"fade"` (automatic conversion when combined with `Codable`)

```swift
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none      // rawValue = "none"
    case fade      // rawValue = "fade"
    case slide     // rawValue = "slide"
    case dissolve  // rawValue = "dissolve"
}
```

#### What Would Happen If Managed as `String`

```swift
// ❌ With String, the compiler cannot detect typos
var transition: String = "fde"   // Typo goes unnoticed
var transition: String = "zoom"  // An undefined value can be assigned

// ✅ With enum, only existing cases can be assigned
var transition: TransitionType = .fade  // The compiler provides completion and validation
```

#### Relevant Code

```swift
enum TransitionType: String, ... {
    case none
    case fade      // TransitionType.fade.rawValue == "fade"
    case slide
    case dissolve
}
```

---

### 9. `CaseIterable` -- Enumerating All Cases

#### Definition

An `enum` that conforms to `CaseIterable` gets an auto-generated property `TransitionType.allCases`, which provides all cases as an array.

#### Why It Is Used Here

When displaying a list of animation types in a UI picker (selection control), `allCases` can dynamically retrieve all options. Even when a new case is added, the UI-side code does not need to be changed.

```swift
// Example of a picker using allCases (how it would look in the Presentation layer)
ForEach(TransitionType.allCases, id: \.self) { type in
    Text(type.rawValue)
}
```

#### What Would Happen Without `CaseIterable`

```swift
// ❌ Managing the array manually
let allTransitions: [TransitionType] = [.none, .fade, .slide, .dissolve]
// You must be careful to update this array every time a case is added
```

#### Relevant Code

```swift
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
//                                                ^^^^^^^^^^^^
    case none
    case fade
    case slide
    case dissolve
}
// TransitionType.allCases → [.none, .fade, .slide, .dissolve]
```

---

### 10. `Codable` -- Encoding/Decoding

#### Definition

`Codable` is a type alias for `Encodable & Decodable`. When you conform to it, the compiler auto-generates code that can **encode** the type into an external format such as JSON, and **decode** it back from an external format.

#### Why It Is Used Here

`SlideshowConfig` and `TransitionType` conform to `Codable`. This is used when saving slideshow settings to disk or communicating with a server.

```swift
let config = SlideshowConfig(duration: .five, transition: .fade, loop: true)

// Encode: Swift type → JSON
let data = try JSONEncoder().encode(config)
// {"duration":"5","transition":"fade","loop":true}
// ↑ SlideDuration.five has rawValue "5", so the JSON contains "5", not "five"

// Decode: JSON → Swift type
let restored = try JSONDecoder().decode(SlideshowConfig.self, from: data)
```

Because `TransitionType` has `String` as its rawValue, it is saved in JSON as a human-readable string like `"fade"`.

#### What Would Happen Without `Codable`

```swift
// ❌ Writing encode/decode manually (can run to dozens of lines)
func encode() -> [String: Any] {
    return [
        "duration": duration.rawValue,
        "transition": transition.rawValue,
        "loop": loop
    ]
}
static func decode(from dict: [String: Any]) throws -> SlideshowConfig {
    guard let durationRaw = dict["duration"] as? String,
          let duration = SlideDuration(rawValue: durationRaw),
          ...
    else { throw DecodingError.dataCorrupted(...) }
    return SlideshowConfig(...)
}
```

#### Relevant Code

```swift
struct SlideshowConfig: Equatable, Sendable, Codable { ... }
//                                           ^^^^^^^ Auto-generated encode/decode
```

---

### 11. `static let default` -- A Type's Default Value

#### Definition

`static let` is a "constant that belongs to the type itself rather than to an instance." `default` is enclosed in backticks (`` ` ``) because `default` is a Swift reserved word (the `default:` label in `switch` statements).

#### Why It Is Used Here

It defines "recommended initial values" used when creating a new slideshow or resetting settings, all in one place.

```swift
static let `default` = SlideshowConfig(
    duration: .five,       // Display for 5 seconds
    transition: .fade,     // Transition with a fade
    loop: true             // Loop playback
)
```

Callers can retrieve it simply by writing `SlideshowConfig.default`.

#### What Would Happen Without `static let default`

```swift
// ❌ Scattering default values across multiple locations
// Both in the View and UseCase, you write the same values every time
// → When one is changed, others may be missed
let config1 = SlideshowConfig(duration: .five, transition: .fade, loop: true)
let config2 = SlideshowConfig(duration: .five, transition: .fade, loop: true)  // Duplication
```

#### Relevant Code

```swift
static let `default` = SlideshowConfig(
    duration: .five,
    transition: .fade,
    loop: true
)
```

```swift
// The same pattern in TransitionType
static let `default` = TransitionType.fade
```

---

### 12. Factory Method `static func create(...)` -- Entity Creation Pattern

#### Definition

A factory method is a "static method that encapsulates the rules for creating an object." Instead of calling `init` directly, `Slideshow` is created using `Slideshow.create(...)`.

#### Why It Is Used Here

Creating a `Slideshow` requires multiple steps: "generating an ID," "building the slide list," and "setting the creation date." By encapsulating these in a factory method:

1. Callers do not need to know the complex initialization logic
2. If the creation rules change, only the `create` method needs to be modified
3. ID generation with `id: UUID()` always happens here, preventing duplicate ID management

```swift
static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
    Slideshow(
        id: UUID(),                            // ID is always generated here
        name: name,
        slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
        config: config,
        createdAt: Date()                      // Creation date is always set here
    )
}
```

#### What Would Happen Without a Factory Method

```swift
// ❌ The caller handles all initialization every time
let slideshow = Slideshow(
    id: UUID(),           // ← Caller must write UUID()
    name: name,
    slides: localIdentifiers.enumerated().map { index, id in
        Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
    },
    config: config,
    createdAt: Date()    // ← Caller must write the creation date too
)
// This creation logic gets duplicated across UseCases, Views, etc.
```

#### Relevant Code

```swift
static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
    Slideshow(
        id: UUID(),
        name: name,
        slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
        config: config,
        createdAt: Date()
    )
}
```

---

### 13. `func applying(...) -> Self` -- Immutable Update Pattern

#### Definition

The "immutable update pattern" is a technique where, instead of modifying the original object, **a new copy with the changes applied is returned**. `func applying(...) -> Slideshow` and `func updating(...) -> Slideshow` implement this pattern.

#### Why It Is Used Here

Since `Slideshow` is a `struct` (value type), you could directly mutate its properties. However, this pattern offers advantages:

1. **Clear intent**: `slideshow.applying(config: newConfig)` is more readable than `slideshow.config = newConfig` in conveying the intent of "update and obtain a new value"
2. **Original value is safe**: Calling `applying` does not change the original `slideshow` variable
3. **Chainable**: Multiple changes can be chained as `.applying(...).updating(...)`

Let's look at the internal implementation:

```swift
func applying(config: SlideshowConfig) -> Slideshow {
    var updated = self         // 1. Create a copy of self (it's a struct, so it's copied)
    updated.config = config    // 2. Modify the config on the copy
    return updated             // 3. Return the modified copy (the original self is unchanged)
}
```

#### What Would Happen Without This Pattern

```swift
// ❌ Mutating directly (this works, but the intent is less clear)
var slideshow = Slideshow.create(...)
slideshow.config = newConfig   // Harder to track where and what changed

// ❌ If the UseCase layer directly mutates properties,
//    domain logic ("what should be updated together") leaks into the UseCase
```

Note that `updating(name:localIdentifiers:)` updates `name` and `slides` **simultaneously**. The business rule "when the name changes, the slide list must also be regenerated" is encapsulated within this method.

#### Relevant Code

```swift
func applying(config: SlideshowConfig) -> Slideshow {
    var updated = self
    updated.config = config
    return updated
}

func updating(name: String, localIdentifiers: [String]) -> Slideshow {
    var updated = self
    updated.name = name
    updated.slides = Slideshow.makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0)
    return updated
}
```

---

## Pitfalls Learned in Practice

Here are two pitfalls drawn from issues that actually occurred during the development of this project.

---

### Pitfall 1: Don't Pack Business Logic into Entities

#### What Happens

When you keep adding methods to entities because "it's convenient," what should be a data container turns into a blob of business logic.
In practice, `Slideshow` had methods for slide navigation, but these could be computed from their arguments alone and did not depend on the entity's own state (`self`). Such methods belong in a Domain Service.

#### Decision Criteria

- The method uses `self`'s stored properties --> It can stay in the entity (e.g., `applying(config:)`)
- The method can compute its result from arguments alone --> It should be moved to a Domain Service

```swift
// ❌ A method that should not be in the entity (does not use self's state)
struct Slideshow {
    func nextSlideIndex(from currentIndex: Int) -> Int {
        // Can be computed from just currentIndex and slides.count,
        // but playback logic is the responsibility of PlaybackDomainService
        (currentIndex + 1) % slides.count
    }
}

// ✅ Move to a Domain Service (actual code from PlaybackDomainService.swift)
final class PlaybackDomainService: PlaybackDomainServiceProtocol, Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex < totalSlides - 1 { return currentIndex + 1 }
        return loop ? 0 : nil
    }
}
```

By keeping entities as **pure data containers** and placing behavior in Domain Services, responsibilities become clear and testing becomes easier.

---

### Pitfall 2: Represent Fixed Choices with `enum`

#### What Happens

Over-interpreting the rule "Domain layer types should be `struct`" can lead to expressing fixed choices with `struct` + `static let`. However, Swift's `enum` is also a value type, so it does not violate the Domain layer rule (that types should be value types).

```swift
// ❌ Expressed with struct + static let (switch exhaustiveness checking does not work)
struct TransitionType: Equatable, Sendable {
    let rawValue: String
    static let none = TransitionType(rawValue: "none")
    static let fade = TransitionType(rawValue: "fade")
    static let slide = TransitionType(rawValue: "slide")
    static let dissolve = TransitionType(rawValue: "dissolve")
}

// With this approach, even if you list all cases in a switch statement,
// the compiler cannot detect missing cases
switch transition {
case .none: ...
case .fade: ...
// Forgetting .slide and .dissolve still compiles
default: break  // ← default is required, and you can't notice omissions
}
```

```swift
// ✅ With enum, switch exhaustiveness checking works
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve
}

switch transition {
case .none: ...
case .fade: ...
// Not writing .slide and .dissolve causes a compile error ← Safe!
}
```

**Guidelines for choosing:**
- **Choices are fixed and won't grow or shrink** --> `enum` (compiler exhaustiveness checking is available)
- **May be extended in the future** --> `struct` or protocol

---

## Summary: What You Can Learn from These Files

### Swift Language Fundamentals

| Concept | What You Learned |
|---|---|
| `struct` vs `class` | Value types are copied. The Domain layer stays safe and simple with value types |
| `let` vs `var` | Things that must not change are protected by the compiler with `let` |
| `Optional` (`?`) | "Absence" is represented by `nil`. The compiler detects forgotten nil handling |
| `UUID` | A collision-free unique identifier |
| `enum` + `rawValue` | Fixed choices handled in a type-safe manner |

### Protocols

| Protocol | Effect |
|---|---|
| `Identifiable` | Can be passed directly to SwiftUI's `ForEach` |
| `Equatable` | Can be compared with `==`. The compiler auto-generates the implementation |
| `Sendable` | Can be safely passed between threads in Swift 6 |
| `Codable` | JSON conversion/restoration is auto-generated by the compiler |
| `CaseIterable` | All cases can be enumerated with `allCases` |

### Domain Design Patterns

| Pattern | Purpose |
|---|---|
| `static let default` | Centralize default values in one place |
| `static func create(...)` | Encapsulate creation logic within the entity (factory method) |
| `func applying(...) -> Self` | Return a modified copy without destroying the original value (immutable update) |

### Domain Layer Rules

- **No imports other than `Foundation`**: Do not import `SwiftData`, `SwiftUI`, `Photos`, etc.
- **No `class`**: Everything is written as `struct` or `enum` (value types)
- **No UI knowledge**: Do not put display formatters or similar in the Domain layer
- Use `Optional` only for fields that can genuinely be absent in the domain
