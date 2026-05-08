# Testing Practical Guide — Writing Reliable Tests with XCTest

**Category:** Advanced (Cross-Topic Guide)

Testing code that uses Swift's async features or SwiftData has several pitfalls that will trip you up if you don't know about them. This guide compiles the problems actually encountered during 10slide development, along with patterns for making tests run reliably.

---

## Overview

| Testing challenge | Symptom | Resolution pattern |
|-------------------|---------|-------------------|
| `XCTAssertThrowsError` doesn't work with async | Compile error | `do/catch` + `XCTFail` pattern |
| Repository tests need real SwiftData | `ModelContainer` setup required | In-memory `ModelContainer` + real `SwiftDataStore` |
| Unclear how to test `@ModelActor` | Can't distinguish unit from integration | Use protocol mocks vs in-memory containers |
| Timer-based ViewModel tests are slow | Must wait for production `Duration` | Parameterize `Duration` for shorter waits |

---

## 1. XCTAssertThrowsError Doesn't Work with Async — Workaround

### Problem

`XCTAssertThrowsError`'s closure does not support `async`. Attempting to verify errors from async methods results in a compile error.

### Incorrect example

```swift
// ❌ Compile error: async call in an autoclosure that does not support concurrency
func testLoad_whenInvalidYAML_throws() async throws {
    await XCTAssertThrowsError(try await sut.load())
}
```

`XCTAssertThrowsError`'s argument is an `@autoclosure`, and no overload exists that accepts an `async` closure.

### Correct example

```swift
// ✅ do/catch + XCTFail pattern
func testLoad_whenInvalidYAML_throws() async {
    do {
        _ = try await sut.load()
        XCTFail("Expected load() to throw")  // If we reach here, the test fails
    } catch {
        // Error was thrown as expected
    }
}
```

### When you want to verify the specific error type

```swift
// ✅ Verify a specific error type
func testLoad_whenFileNotFound_throwsConfigError() async {
    do {
        _ = try await sut.load()
        XCTFail("Expected load() to throw ConfigError.fileNotFound")
    } catch let error as ConfigError {
        XCTAssertEqual(error, .fileNotFound)
    } catch {
        XCTFail("Unexpected error type: \(error)")
    }
}
```

### Rules

- Use `do/catch` + `XCTFail` for async error tests
- Do not use `try?` to swallow errors — it makes it impossible to tell whether an error was thrown
- `XCTestExpectation` + `fulfill()` is unnecessary — `do/catch` is simpler

---

## 2. Repository Tests Use Real SwiftDataStore with In-Memory Containers

### Problem

In 10slide, Repositories depend on `SwiftDataStoreProtocol` (a `@ModelActor` actor). How should they be tested? Since the Repository's core logic involves building `FetchDescriptor`s and `#Predicate` expressions — which only work with real SwiftData — **Repository tests are integration tests** that use a real `SwiftDataStore` with an in-memory `ModelContainer`.

### Actual test pattern (from `SlideshowRepositoryTests`)

```swift
final class SlideshowRepositoryTests: XCTestCase {
    private var sut: SlideshowRepository!
    private var store: SwiftDataStore!
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        store = SwiftDataStore(modelContainer: container)
        sut = SlideshowRepository(store: store)
    }

    override func tearDown() async throws {
        sut = nil
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testFetchAll_onEmpty_returnsEmptyArray() async throws {
        let result = try await sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }
}
```

### When to use each approach

| Test target | Strategy | SwiftData dependency |
|-------------|----------|---------------------|
| `SwiftDataStore` (Infrastructure) | Integration — in-memory `ModelContainer` | Real |
| Repository | Integration — real `SwiftDataStore` + in-memory container | Real |
| UseCase | Unit test — mock the Repository protocol | None |
| ViewModel | Unit test — mock the UseCase protocol | None |

### Rules

- Repository tests are **integration tests** — they use a real `SwiftDataStore` because `FetchDescriptor` and `#Predicate` only work with real SwiftData
- Always use `isStoredInMemoryOnly: true` — on-disk stores leak state between tests
- Set `sut`, `store`, and `container` to `nil` in `tearDown()` to prevent state leaks

---

## 3. UseCase and ViewModel Testing — Protocol Mocks

### Problem

UseCases depend on Domain Services, and ViewModels depend on UseCases. How do you test them without pulling in the entire dependency chain?

### Pattern: Mock at the protocol boundary

Each layer defines a protocol for its dependencies. In tests, create a `Mock*` class that implements the protocol with configurable return values and call counters.

```swift
// ✅ Mock for an async use case (from SlideshowPlayerViewModelTests)
final class MockLoadSlideImageUseCase: AsyncUseCase, @unchecked Sendable {
    // Minimal valid 1x1 pixel PNG
    var executeResult: Data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUg...")!
    var executeCallCount = 0
    var throwOnExecute = false

    func execute(_ request: LoadSlideImageRequest) async throws -> Data {
        executeCallCount += 1
        if throwOnExecute { throw SlideshowPlayerTestError.intentional }
        return executeResult
    }
}
```

```swift
// ✅ Mock for a sync use case — contains real navigation logic (from SlideshowPlayerViewModelTests)
final class MockAdvanceSlideUseCase: SyncUseCase, @unchecked Sendable {
    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        let next = request.currentIndex + 1
        if next < request.totalSlides {
            return next
        } else if request.loop {
            return 0
        }
        return nil
    }
}
```

### ViewModel tests require `@MainActor`

ViewModels are annotated `@MainActor`, so test classes that create and interact with them must also be `@MainActor`:

```swift
@MainActor
final class SlideshowPlayerViewModelTests: XCTestCase {
    private var mockLoadSlideImage: MockLoadSlideImageUseCase!
    private var sut: SlideshowPlayerViewModel!

    override func setUp() {
        mockLoadSlideImage = MockLoadSlideImageUseCase()
        sut = SlideshowPlayerViewModel(
            slideshow: testSlideshow,
            loadSlideImage: mockLoadSlideImage,
            ...
            filmstripHideDuration: .milliseconds(50)  // Short duration for fast tests
        )
    }
}
```

### Choosing the right testing strategy

| Test target | Test type | SwiftData dependency | Mock target |
|-------------|----------|---------------------|-------------|
| `SwiftDataStore` (Infrastructure) | Integration test | In-memory `ModelContainer` | None |
| Repository | Integration test | In-memory `ModelContainer` + real store | None |
| UseCase | Unit test | None | Domain Service protocol |
| ViewModel | Unit test | None | UseCase protocol |

### Rules

- Mock at the protocol boundary — never mock concrete classes
- Use `@unchecked Sendable` only on mock types where mutation is controlled by test setup
- ViewModel test classes must be annotated `@MainActor`
- Both `AsyncUseCase` and `SyncUseCase` mocks are needed (the codebase uses both)

---

## 4. Testing Timer-Based ViewModels — Parameterize the Duration

### Problem

When a ViewModel has timer-driven features (auto-hide, auto-advance, etc.), testing with production `Duration` values (e.g., 3 seconds) is too slow. But if the `Duration` is hardcoded, it cannot be shortened for tests.

### Incorrect example

```swift
// ❌ Duration is hardcoded and cannot be changed in tests
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    var showFilmstrip = true

    func startAutoHide() {
        Task {
            try await Task.sleep(for: .seconds(3))  // Test has to wait 3 seconds
            showFilmstrip = false
        }
    }
}
```

```swift
// ❌ Test is slow
func testAutoHide() async throws {
    sut.startAutoHide()
    try await Task.sleep(for: .seconds(4))  // Waiting 4 seconds...
    XCTAssertFalse(sut.showFilmstrip)
}
```

### Correct example

```swift
// ✅ Make Duration an init parameter with a default value to preserve production behavior
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    var showFilmstrip = true
    private let filmstripHideDuration: Duration

    init(
        ...,
        filmstripHideDuration: Duration = .seconds(3)  // Production default
    ) {
        self.filmstripHideDuration = filmstripHideDuration
    }

    func startAutoHide() {
        Task {
            try await Task.sleep(for: filmstripHideDuration)
            showFilmstrip = false
        }
    }
}
```

```swift
// ✅ Inject a short Duration in tests — completes quickly
func testAutoHide() async throws {
    sut = SlideshowPlayerViewModel(
        ...,
        filmstripHideDuration: .milliseconds(50)  // Completes in 50ms
    )

    sut.startAutoHide()
    try await Task.sleep(for: .milliseconds(100))  // Sufficient wait time
    XCTAssertFalse(sut.showFilmstrip)
}
```

### Criteria for parameterization

| Target | Parameterize? | Reason |
|--------|--------------|--------|
| Duration that changes state via a timer | Yes | Must be observable in tests |
| Animation Duration | **No** | State changes are not observed in tests |
| Debounce Duration | Yes | Post-debounce state needs to be verified in tests |

### Rules

- Make any `Duration` that needs to be observed in tests a parameter of `init`
- Specify the production default value as a default argument in `init` — callers need no changes
- Use `async throws` tests + `Task.sleep` rather than `XCTestExpectation` + `fulfill()`

---

## Summary

| Pattern | Problem | Solution |
|---------|---------|----------|
| `do/catch` + `XCTFail` | `XCTAssertThrowsError` does not support async | `do { try await ...; XCTFail() } catch { }` |
| In-memory `ModelContainer` | Repository tests need real SwiftData | `isStoredInMemoryOnly: true` + real `SwiftDataStore` |
| Protocol mock | UseCase/ViewModel unit tests | Mock at the protocol boundary with call counters |
| `@MainActor` test class | ViewModel tests require main actor | Annotate test class with `@MainActor` |
| Duration parameterization | Timer-based ViewModel tests are slow | `init` parameter + default value |

### Principles

1. **Repository tests are integration tests** — they need real SwiftData because `FetchDescriptor` and `#Predicate` only work with it
2. **UseCase and ViewModel tests are unit tests** — eliminate dependencies with protocol mocks
3. **Run integration tests in-memory** — prevent disk state from contaminating tests
4. **Inject Duration for time-dependent tests** — achieve both speed and reliability
