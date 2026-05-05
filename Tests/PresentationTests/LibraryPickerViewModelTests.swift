import XCTest
@testable import TenSlide

// MARK: - Error

private enum SlideshowLibraryViewModelTestError: Error {
    case intentional
}

// MARK: - Mock: FetchSlideshowsUseCase

final class MockFetchSlideshowsUseCase: FetchSlideshowsUseCaseProtocol, @unchecked Sendable {
    var executeResult: [SlideshowResponse] = []
    var executeCallCount = 0
    var throwOnExecute = false
    var delay: Duration = .zero

    func execute(_ request: FetchSlideshowsRequest) async throws -> [SlideshowResponse] {
        executeCallCount += 1
        if delay != .zero {
            try? await Task.sleep(for: delay)
        }
        if throwOnExecute { throw SlideshowLibraryViewModelTestError.intentional }
        return executeResult
    }
}

// MARK: - Mock: DeleteSlideshowUseCase

final class MockDeleteSlideshowUseCaseForLibrary: DeleteSlideshowUseCaseProtocol, @unchecked Sendable {
    var executeCallCount = 0
    var throwOnExecute = false

    func execute(_ request: DeleteSlideshowRequest) async throws {
        executeCallCount += 1
        if throwOnExecute { throw SlideshowLibraryViewModelTestError.intentional }
    }
}

// MARK: - SlideshowLibraryViewModelTests

@MainActor
final class SlideshowLibraryViewModelTests: XCTestCase {
    private var sut: SlideshowLibraryViewModel!
    private var mockFetchSlideshows: MockFetchSlideshowsUseCase!
    private var mockDeleteSlideshow: MockDeleteSlideshowUseCaseForLibrary!

    override func setUp() {
        super.setUp()
        mockFetchSlideshows = MockFetchSlideshowsUseCase()
        mockDeleteSlideshow = MockDeleteSlideshowUseCaseForLibrary()
        sut = SlideshowLibraryViewModel(
            fetchSlideshows: mockFetchSlideshows,
            deleteSlideshow: mockDeleteSlideshow
        )
    }

    override func tearDown() {
        sut = nil
        mockFetchSlideshows = nil
        mockDeleteSlideshow = nil
        super.tearDown()
    }

    // MARK: - loadLibrary()

    func testLoadLibrary_populatesSlideshowsFromUseCase() async {
        mockFetchSlideshows.executeResult = [
            SlideshowResponse(id: UUID(), name: "Show 1", slides: [], config: .default, createdAt: Date()),
            SlideshowResponse(id: UUID(), name: "Show 2", slides: [], config: .default, createdAt: Date())
        ]
        await sut.loadLibrary()
        XCTAssertEqual(sut.slideshows.count, 2)
    }

    func testLoadLibrary_callsFetchSlideshowsUseCaseOnce() async {
        await sut.loadLibrary()
        XCTAssertEqual(mockFetchSlideshows.executeCallCount, 1)
    }

    func testLoadLibrary_withEmptyResult_slideshowsIsEmpty() async {
        mockFetchSlideshows.executeResult = []
        await sut.loadLibrary()
        XCTAssertTrue(sut.slideshows.isEmpty)
    }

    func testLoadLibrary_isLoadingFalseAfterCompletion() async {
        await sut.loadLibrary()
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadLibrary_isLoadingTrueWhileExecuting() async throws {
        mockFetchSlideshows.delay = .milliseconds(200)
        let task = Task { await self.sut.loadLibrary() }
        try await Task.sleep(for: .milliseconds(50))
        let isLoading = sut.isLoading
        await task.value
        XCTAssertTrue(isLoading)
    }

    func testLoadLibrary_whenUseCaseThrows_setsErrorMessage() async {
        mockFetchSlideshows.throwOnExecute = true
        await sut.loadLibrary()
        XCTAssertEqual(
            sut.errorMessage,
            SlideshowLibraryViewModelTestError.intentional.localizedDescription
        )
    }

    func testLoadLibrary_whenUseCaseThrows_slideshowsRemainsEmpty() async {
        mockFetchSlideshows.throwOnExecute = true
        await sut.loadLibrary()
        XCTAssertTrue(sut.slideshows.isEmpty)
    }

    func testLoadLibrary_whenUseCaseThrows_isLoadingFalseAfterCompletion() async {
        mockFetchSlideshows.throwOnExecute = true
        await sut.loadLibrary()
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - deleteSlideshow(id:)

    func testDeleteSlideshow_callsDeleteUseCaseOnce() async {
        let id = UUID()
        mockFetchSlideshows.executeResult = [
            SlideshowResponse(id: id, name: "Show", slides: [], config: .default, createdAt: Date())
        ]
        await sut.loadLibrary()
        await sut.deleteSlideshow(id: id)
        XCTAssertEqual(mockDeleteSlideshow.executeCallCount, 1)
    }

    func testDeleteSlideshow_removesFromLocalList() async {
        let id = UUID()
        mockFetchSlideshows.executeResult = [
            SlideshowResponse(id: id, name: "Show", slides: [], config: .default, createdAt: Date())
        ]
        await sut.loadLibrary()
        await sut.deleteSlideshow(id: id)
        XCTAssertTrue(sut.slideshows.isEmpty)
    }
}
