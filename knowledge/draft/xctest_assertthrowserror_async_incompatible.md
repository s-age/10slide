---
type: gotcha
context: when writing async unit tests that verify error handling
keywords: [XCTest, async/await, error handling, throwsError]
---

## What

`XCTAssertThrowsError` does not accept `async` closures. In Swift async/await tests, the pattern fails at compile time:

```swift
// ❌ Does not compile
func testLoad_whenFileContainsInvalidYAML_throws() async throws {
    await XCTAssertThrowsError(try await sut.load())
}
// error: 'async' call in an autoclosure that does not support concurrency
```

## Do

Use `do/catch` instead:

```swift
// ✅ Works
func testLoad_whenFileContainsInvalidYAML_throws() async {
    do {
        _ = try await sut.load()
        XCTFail("Expected load() to throw")
    } catch {
        // expected — error was thrown as intended
    }
}
```

## Don't

- Don't force-unwrap or suppress errors to avoid the pattern (`try? sut.load()` masks errors).
- Don't use `XCTestExpectation` — the `do/catch` approach is simpler and idiomatic for async.

## See also

- `test-unit.md`: "Async tests" section shows `async throws` on test methods (required for async code under test).
