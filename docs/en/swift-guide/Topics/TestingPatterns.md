# Testing Practical Guide — Writing Reliable Tests with XCTest

**Category:** Advanced (Cross-Topic Guide)

Testing code that uses Swift's async features or SwiftData has several pitfalls that will trip you up if you don't know about them. This guide compiles the problems actually encountered during 10slide development, along with patterns for making tests run reliably.

---

## Overview

| Testing challenge | Symptom | Resolution pattern |
|-------------------|---------|-------------------|
| `XCTAssertThrowsError` doesn't work with async | Compile error | `do/catch` + `XCTFail` pattern |
| `@Model` test fixtures are heavy | `ModelContainer` setup required | Create `@Model` directly without a context |
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

## 2. @Model Instances Can Be Created Without a ModelContext — Lightweight Test Fixtures

### Problem

Setting up a `ModelContainer` + `ModelContext` for every test that uses `@Model` makes tests heavy. In fact, `@Model` instances can be created and manipulated **without a context**.

### Why does it work?

The `@Model` macro internally generates a backing storage called `_$backingData`. This operates in-memory even without a context. Persistence operations (save/fetch) require a context, but reading and writing properties and assigning relationships work entirely in-memory.

### Incorrect example

```swift
// ❌ Setting up ModelContainer for every unit test — overkill
func setUp() async throws {
    let schema = Schema([SlideshowModel.self, SlideModel.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = ModelContext(container)

    let model = SlideshowModel(id: UUID(), name: "Test")
    context.insert(model)
    try context.save()
    // ... this is integration test setup
}
```

### Correct example

```swift
// ✅ Create @Model fixtures without a context (for unit tests)
func setUp() {
    let model = SlideshowModel(id: UUID(), name: "Test")
    model.slides = [
        SlideModel(id: UUID(), localIdentifier: "slide-1", order: 0, duration: 3.0),
        SlideModel(id: UUID(), localIdentifier: "slide-2", order: 1, duration: 5.0),
    ]

    // Can be passed directly to mock data sources
    mockDataSource.fetchAllResult = [model]
}
```

### When is a ModelContainer needed?

| Test type | ModelContainer | Purpose |
|-----------|---------------|---------|
| Unit test (Repository, etc.) | **Not needed** | Just pass fixtures to the mock |
| Integration test (DataSource, etc.) | **Needed** (in-memory) | Verify actual save/fetch behavior |

### Rules

- In unit tests, create `@Model` instances directly without a context
- Assigning relationship arrays (`model.slides = [...]`) also works without a context
- However, inverse relationships (`slide.slideshow`) are only auto-populated within a context — in tests, only verify the direction you explicitly set

---

## 3. @ModelActor Testing Strategy — Unit Tests vs Integration Tests

### Problem

How should `@ModelActor`-based data sources be tested? The strategy differs between testing the data source itself and testing the Repository that uses it.

### Integration test: Verify actual persistence with an in-memory ModelContainer

To verify the data source's correctness, you need an actual `ModelContainer`. Use an **in-memory configuration** so that data does not persist between tests.

```swift
// ✅ Integration test — verify the data source's actual behavior
final class SlideshowDataSourceTests: XCTestCase {
    private var container: ModelContainer!
    private var sut: SlideshowDataSource!

    override func setUp() async throws {
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        sut = SlideshowDataSource(modelContainer: container)
    }

    func testSaveAndFetchAll() async throws {
        let dto = SlideshowDTO(id: UUID(), name: "Test", slides: [])
        try await sut.save(dto)

        let results = try await sut.fetchAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Test")
    }
}
```

### Unit test: Eliminate SwiftData with protocol mocks

In Repository tests, mock the data source protocol to completely eliminate the SwiftData dependency.

```swift
// ✅ Unit test — mock the data source
final class MockSlideshowDataSource: SlideshowDataSourceProtocol, @unchecked Sendable {
    var fetchAllResult: [SlideshowDTO] = []
    var saveCallCount = 0

    func fetchAll() async throws -> [SlideshowDTO] {
        fetchAllResult
    }

    func save(_ dto: SlideshowDTO) async throws {
        saveCallCount += 1
    }
}

final class SlideshowRepositoryTests: XCTestCase {
    private var mockDataSource: MockSlideshowDataSource!
    private var sut: SlideshowRepository!

    override func setUp() {
        mockDataSource = MockSlideshowDataSource()
        sut = SlideshowRepository(dataSource: mockDataSource)
    }

    func testFetchAll_returnsConvertedEntities() async throws {
        mockDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "Test", slides: [])
        ]

        let results = try await sut.fetchAll()
        XCTAssertEqual(results.count, 1)
    }
}
```

### Choosing the right testing strategy

| Test target | Test type | SwiftData dependency | Mock target |
|-------------|----------|---------------------|-------------|
| DataSource (Infrastructure) | Integration test | In-memory ModelContainer | None |
| Repository | Unit test | None | DataSource protocol |
| UseCase | Unit test | None | Repository protocol |
| ViewModel | Unit test | None | UseCase protocol |

### Rules

- Always use `isStoredInMemoryOnly: true` in integration tests — on-disk stores leak state between tests
- Do not mock `@Model` classes directly — mock at the DTO protocol level
- When sharing the same `ModelContainer` across test methods, reset data at the beginning of each test

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
| Context-free `@Model` | Test fixture setup is heavy | `@Model` can be created without a context |
| Protocol mock | How to unit test `@ModelActor` | Mock at the DTO protocol level |
| In-memory ModelContainer | How to integration test `@ModelActor` | `isStoredInMemoryOnly: true` |
| Duration parameterization | Timer-based ViewModel tests are slow | `init` parameter + default value |

### Principles

1. **Do not touch SwiftData in unit tests** — eliminate dependencies with protocol mocks
2. **Run integration tests in-memory** — prevent disk state from contaminating tests
3. **Inject Duration for time-dependent tests** — achieve both speed and reliability
