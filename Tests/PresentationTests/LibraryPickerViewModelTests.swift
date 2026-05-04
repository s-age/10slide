import XCTest
@testable import TenSlide

// MARK: - Error

private enum LibraryPickerViewModelTestError: Error {
    case intentional
}

// MARK: - Mock: FetchLibraryUseCase

final class MockFetchLibraryUseCase: FetchLibraryUseCaseProtocol, @unchecked Sendable {
    var executeResult: [String] = []
    var executeCallCount = 0
    var throwOnExecute = false
    /// When non-zero, execute() sleeps this long before returning (enables isLoading observation).
    var delay: Duration = .zero

    func execute() async throws -> [String] {
        executeCallCount += 1
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        if throwOnExecute { throw LibraryPickerViewModelTestError.intentional }
        return executeResult
    }
}

// MARK: - Mock: LoadThumbnailUseCase

final class MockLoadThumbnailUseCase: LoadThumbnailUseCaseProtocol, @unchecked Sendable {
    func execute(localIdentifier: String) async throws -> Data { Data() }
}

// MARK: - LibraryPickerViewModelTests

@MainActor
final class LibraryPickerViewModelTests: XCTestCase {
    private var sut: LibraryPickerViewModel!
    private var mockFetchLibrary: MockFetchLibraryUseCase!

    override func setUp() {
        super.setUp()
        mockFetchLibrary = MockFetchLibraryUseCase()
        sut = LibraryPickerViewModel(
            fetchLibrary: mockFetchLibrary,
            loadThumbnail: MockLoadThumbnailUseCase()
        )
    }

    override func tearDown() {
        sut = nil
        mockFetchLibrary = nil
        super.tearDown()
    }

    // MARK: - loadLibrary()

    func testLoadLibrary_populatesIdentifiersFromUseCase() async {
        mockFetchLibrary.executeResult = ["id-1", "id-2", "id-3"]
        await sut.loadLibrary()
        XCTAssertEqual(sut.identifiers, ["id-1", "id-2", "id-3"])
    }

    func testLoadLibrary_callsFetchLibraryUseCaseOnce() async {
        await sut.loadLibrary()
        XCTAssertEqual(mockFetchLibrary.executeCallCount, 1)
    }

    func testLoadLibrary_withEmptyResult_identifiersIsEmpty() async {
        mockFetchLibrary.executeResult = []
        await sut.loadLibrary()
        XCTAssertTrue(sut.identifiers.isEmpty)
    }

    func testLoadLibrary_isLoadingFalseAfterCompletion() async {
        await sut.loadLibrary()
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadLibrary_isLoadingTrueWhileExecuting() async throws {
        // Mock delays 200 ms; we observe isLoading at 50 ms while it's still in-flight.
        mockFetchLibrary.delay = .milliseconds(200)
        let task = Task { await self.sut.loadLibrary() }
        try await Task.sleep(for: .milliseconds(50))
        let isLoading = sut.isLoading
        await task.value
        XCTAssertTrue(isLoading)
    }

    func testLoadLibrary_whenUseCaseThrows_setsErrorMessage() async {
        mockFetchLibrary.throwOnExecute = true
        await sut.loadLibrary()
        XCTAssertEqual(
            sut.errorMessage,
            LibraryPickerViewModelTestError.intentional.localizedDescription
        )
    }

    func testLoadLibrary_whenUseCaseThrows_identifiersRemainsEmpty() async {
        mockFetchLibrary.throwOnExecute = true
        await sut.loadLibrary()
        XCTAssertTrue(sut.identifiers.isEmpty)
    }

    func testLoadLibrary_whenUseCaseThrows_isLoadingFalseAfterCompletion() async {
        mockFetchLibrary.throwOnExecute = true
        await sut.loadLibrary()
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadLibrary_onSuccessfulCall_clearsErrorMessage() async {
        mockFetchLibrary.throwOnExecute = true
        await sut.loadLibrary()               // first call: sets errorMessage
        mockFetchLibrary.throwOnExecute = false
        await sut.loadLibrary()               // second call: must clear errorMessage
        XCTAssertNil(sut.errorMessage)
    }
}
