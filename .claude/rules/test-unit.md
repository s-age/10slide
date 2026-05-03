---
paths:
  - 'Tests/**/*.swift'
---

## File placement and naming

Test files mirror the source structure under `Tests/`. One `XCTestCase` subclass per source file.

```
Tests/
├── DomainTests/
│   └── SlideTests.swift                  # tests Sources/Domain/Entities/Slide.swift
├── RepositoryTests/
│   └── SlideRepositoryTests.swift        # tests Sources/Repositories/.../SlideRepository.swift
└── UseCaseTests/
    └── FetchSlidesUseCaseTests.swift
```

When a single test file would exceed **300 lines**, split it into a subdirectory — do not reduce coverage to fit a line limit.

## Framework

Use **XCTest**.

```swift
import XCTest
@testable import TenSlide

final class SlideRepositoryTests: XCTestCase { ... }
```

## Mock style

**Protocol mocks**: a `final class Mock*` implementing the protocol with call counters and configurable return values.

```swift
final class MockSlideDataSource: SlideDataSourceProtocol, @unchecked Sendable {
    var fetchAllResult: [SlideModel] = []
    var fetchAllCallCount = 0

    func fetchAll() async throws -> [SlideModel] {
        fetchAllCallCount += 1
        return fetchAllResult
    }

    func save(_ model: SlideModel) async throws {}
    func delete(id: UUID) async throws {}
}
```

> Use `@unchecked Sendable` only on mock types where mutation is controlled exclusively by test setup and never concurrent.

## Class under test

Instantiate in `setUp()`, never at type scope.

```swift
final class SlideRepositoryTests: XCTestCase {
    private var sut: SlideRepository!
    private var mockDataSource: MockSlideDataSource!

    override func setUp() {
        super.setUp()
        mockDataSource = MockSlideDataSource()
        sut = SlideRepository(
            slideDataSource: mockDataSource,
            imageDataSource: MockImageDataSource()
        )
    }

    override func tearDown() {
        sut = nil
        mockDataSource = nil
        super.tearDown()
    }
}
```

## Async tests

Use `async throws` on test methods; no `XCTestExpectation` needed for `async/await`.

```swift
func testFetchAll_returnsEntities() async throws {
    mockDataSource.fetchAllResult = [SlideModel(localIdentifier: "abc", order: 0)]
    let result = try await sut.fetchAll()
    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].localIdentifier, "abc")
}
```

## Case structure

- Order: happy path → branch variations → error paths
- `describe`-equivalent: nested types or `// MARK: - <method>` groupings
- Test method names: `test<Method>_<condition>_<expectedOutcome>`

## Assertions express the specification

Write each assertion so it can only pass when the intended contract holds.

```swift
// Bad — passes for the wrong reasons
XCTAssertNotNil(result)

// Good — asserts the specific contract
XCTAssertEqual(result.localIdentifier, "expected-id")
XCTAssertNil(result.title)
```

## One assertion per test method

Each test method tests exactly one behavior.

```swift
// Bad — bundles unrelated assertions
func testSave() async throws {
    try await sut.save(slide, in: slideshowID)
    XCTAssertEqual(mockDataSource.saveCallCount, 1)
    XCTAssertEqual(mockDataSource.savedModel?.id, slide.id)
}

// Good — one behavior per method
func testSave_callsDataSourceOnce() async throws {
    try await sut.save(slide, in: slideshowID)
    XCTAssertEqual(mockDataSource.saveCallCount, 1)
}

func testSave_persistsCorrectID() async throws {
    try await sut.save(slide, in: slideshowID)
    XCTAssertEqual(mockDataSource.savedModel?.id, slide.id)
}
```

## What NOT to do

- Never test implementation details — test the observable behavior (protocol contract)
- Never leave `XCTAssert(true)` placeholder tests — implement or delete them
- Never import concrete infrastructure classes in tests — mock at the protocol boundary
- Never define more than one `XCTestCase` subclass per file
- Never use `XCTestExpectation` when `async/await` suffices
