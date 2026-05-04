import XCTest
@testable import TenSlide

// MARK: - Error

private enum CreateSlideshowViewModelTestError: Error {
    case intentional
}

// MARK: - Mock: CreateSlideshowUseCase

final class MockCreateSlideshowUseCase: CreateSlideshowUseCaseProtocol, @unchecked Sendable {
    var executeResult: Slideshow = Slideshow(
        id: UUID(), name: "Mock", slides: [], config: .default, createdAt: Date()
    )
    var executeCallCount = 0
    var lastReceivedName: String?
    var lastReceivedIdentifiers: [String]?
    var lastReceivedConfig: SlideshowConfig?
    var throwOnExecute = false

    func execute(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        executeCallCount += 1
        lastReceivedName = name
        lastReceivedIdentifiers = localIdentifiers
        lastReceivedConfig = config
        if throwOnExecute { throw CreateSlideshowViewModelTestError.intentional }
        return executeResult
    }
}

// MARK: - CreateSlideshowViewModelTests

@MainActor
final class CreateSlideshowViewModelTests: XCTestCase {
    private var sut: CreateSlideshowViewModel!
    private var mockCreateSlideshow: MockCreateSlideshowUseCase!

    override func setUp() {
        super.setUp()
        mockCreateSlideshow = MockCreateSlideshowUseCase()
        sut = CreateSlideshowViewModel(createSlideshow: mockCreateSlideshow)
    }

    override func tearDown() {
        sut = nil
        mockCreateSlideshow = nil
        super.tearDown()
    }

    // MARK: - createSlideshow()

    func testCreateSlideshow_callsUseCaseOnce() async {
        _ = await sut.createSlideshow()
        XCTAssertEqual(mockCreateSlideshow.executeCallCount, 1)
    }

    func testCreateSlideshow_passesSlideshowNameToUseCase() async {
        sut.slideshowName = "Summer Vacation"
        _ = await sut.createSlideshow()
        XCTAssertEqual(mockCreateSlideshow.lastReceivedName, "Summer Vacation")
    }

    func testCreateSlideshow_passesSelectedIdentifiersToUseCase() async {
        sut.toggleSelection("id-1")
        sut.toggleSelection("id-2")
        _ = await sut.createSlideshow()
        let received = Set(mockCreateSlideshow.lastReceivedIdentifiers ?? [])
        XCTAssertEqual(received, Set(["id-1", "id-2"]))
    }

    func testCreateSlideshow_withEmptyIdentifiers_passesEmptyArrayToUseCase() async {
        _ = await sut.createSlideshow()
        XCTAssertTrue(mockCreateSlideshow.lastReceivedIdentifiers?.isEmpty == true)
    }

    func testCreateSlideshow_passesSelectedDurationInConfig() async {
        sut.selectedDuration = .thirty
        _ = await sut.createSlideshow()
        XCTAssertEqual(mockCreateSlideshow.lastReceivedConfig?.duration, .thirty)
    }

    func testCreateSlideshow_passesSelectedTransitionInConfig() async {
        sut.selectedTransition = .slide
        _ = await sut.createSlideshow()
        XCTAssertEqual(mockCreateSlideshow.lastReceivedConfig?.transition, .slide)
    }

    func testCreateSlideshow_returnsSlideshowFromUseCase() async {
        let expected = Slideshow(id: UUID(), name: "My Show", slides: [], config: .default, createdAt: Date())
        mockCreateSlideshow.executeResult = expected
        let result = await sut.createSlideshow()
        XCTAssertEqual(result?.id, expected.id)
    }

    func testCreateSlideshow_isLoadingFalseAfterCompletion() async {
        _ = await sut.createSlideshow()
        XCTAssertFalse(sut.isLoading)
    }

    func testCreateSlideshow_whenUseCaseThrows_setsErrorMessage() async {
        mockCreateSlideshow.throwOnExecute = true
        _ = await sut.createSlideshow()
        XCTAssertEqual(
            sut.errorMessage,
            CreateSlideshowViewModelTestError.intentional.localizedDescription
        )
    }

    func testCreateSlideshow_whenUseCaseThrows_returnsNil() async {
        mockCreateSlideshow.throwOnExecute = true
        let result = await sut.createSlideshow()
        XCTAssertNil(result)
    }

    func testCreateSlideshow_whenUseCaseThrows_isLoadingFalseAfterCompletion() async {
        mockCreateSlideshow.throwOnExecute = true
        _ = await sut.createSlideshow()
        XCTAssertFalse(sut.isLoading)
    }
}
