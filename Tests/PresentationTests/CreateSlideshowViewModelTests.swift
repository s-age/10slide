import XCTest
@testable import TenSlide

// MARK: - Error

private enum CreateSlideshowViewModelTestError: Error {
    case intentional
}

// MARK: - Mock: CreateSlideshowUseCase

final class MockCreateSlideshowUseCase: CreateSlideshowUseCaseProtocol, @unchecked Sendable {
    var executeResult: SlideshowResponse = SlideshowResponse(
        id: UUID(), name: "Mock", slides: [], config: .default, createdAt: Date()
    )
    var executeCallCount = 0
    var lastReceivedRequest: CreateSlideshowRequest?
    var throwOnExecute = false

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        executeCallCount += 1
        lastReceivedRequest = request
        if throwOnExecute { throw CreateSlideshowViewModelTestError.intentional }
        return executeResult
    }
}

// MARK: - Mock: UpdateSlideshowUseCase

final class MockUpdateSlideshowUseCaseForCreate: UpdateSlideshowUseCaseProtocol, @unchecked Sendable {
    var executeResult: SlideshowResponse = SlideshowResponse(
        id: UUID(), name: "Mock", slides: [], config: .default, createdAt: Date()
    )
    var executeCallCount = 0

    func execute(_ request: UpdateSlideshowRequest) async throws -> SlideshowResponse {
        executeCallCount += 1
        return executeResult
    }
}

// MARK: - Mock: AddDroppedFilesUseCase

final class MockAddDroppedFilesUseCaseForCreate: AddDroppedFilesUseCaseProtocol, @unchecked Sendable {
    var executeResult: [String] = []

    func execute(_ request: AddDroppedFilesRequest) throws -> [String] {
        executeResult
    }
}

// MARK: - CreateSlideshowViewModelTests

@MainActor
final class CreateSlideshowViewModelTests: XCTestCase {
    private var sut: CreateSlideshowViewModel!
    private var mockCreateSlideshow: MockCreateSlideshowUseCase!
    private var mockUpdateSlideshow: MockUpdateSlideshowUseCaseForCreate!
    private var mockAddDroppedFiles: MockAddDroppedFilesUseCaseForCreate!

    override func setUp() {
        super.setUp()
        mockCreateSlideshow = MockCreateSlideshowUseCase()
        mockUpdateSlideshow = MockUpdateSlideshowUseCaseForCreate()
        mockAddDroppedFiles = MockAddDroppedFilesUseCaseForCreate()
        sut = CreateSlideshowViewModel(
            createSlideshow: mockCreateSlideshow,
            updateSlideshow: mockUpdateSlideshow,
            addDroppedFiles: mockAddDroppedFiles
        )
    }

    override func tearDown() {
        sut = nil
        mockCreateSlideshow = nil
        mockUpdateSlideshow = nil
        mockAddDroppedFiles = nil
        super.tearDown()
    }

    // MARK: - saveSlideshow()

    func testSaveSlideshow_callsUseCaseOnce() async {
        sut.slideshowName = "Test"
        sut.addFiles([])
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertEqual(mockCreateSlideshow.executeCallCount, 1)
    }

    func testSaveSlideshow_passesSlideshowNameToUseCase() async {
        sut.slideshowName = "Summer Vacation"
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertEqual(mockCreateSlideshow.lastReceivedRequest?.name, "Summer Vacation")
    }

    func testSaveSlideshow_passesSelectedDurationInRequest() async {
        sut.slideshowName = "Test"
        sut.selectedDuration = .thirty
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertEqual(mockCreateSlideshow.lastReceivedRequest?.duration, .thirty)
    }

    func testSaveSlideshow_passesSelectedTransitionInRequest() async {
        sut.slideshowName = "Test"
        sut.selectedTransition = .slide
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertEqual(mockCreateSlideshow.lastReceivedRequest?.transition, .slide)
    }

    func testSaveSlideshow_returnsSlideshowResponseFromUseCase() async {
        let expectedID = UUID()
        mockCreateSlideshow.executeResult = SlideshowResponse(
            id: expectedID, name: "My Show", slides: [], config: .default, createdAt: Date()
        )
        sut.slideshowName = "My Show"
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        let result = await sut.saveSlideshow()
        XCTAssertEqual(result?.id, expectedID)
    }

    func testSaveSlideshow_isLoadingFalseAfterCompletion() async {
        sut.slideshowName = "Test"
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertFalse(sut.isLoading)
    }

    func testSaveSlideshow_whenUseCaseThrows_setsErrorMessage() async {
        mockCreateSlideshow.throwOnExecute = true
        sut.slideshowName = "Test"
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertEqual(
            sut.errorMessage,
            CreateSlideshowViewModelTestError.intentional.localizedDescription
        )
    }

    func testSaveSlideshow_whenUseCaseThrows_returnsNil() async {
        mockCreateSlideshow.throwOnExecute = true
        sut.slideshowName = "Test"
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        let result = await sut.saveSlideshow()
        XCTAssertNil(result)
    }

    func testSaveSlideshow_whenUseCaseThrows_isLoadingFalseAfterCompletion() async {
        mockCreateSlideshow.throwOnExecute = true
        sut.slideshowName = "Test"
        mockAddDroppedFiles.executeResult = ["id-1"]
        sut.addFiles([URL(fileURLWithPath: "/tmp/img.jpg")])
        _ = await sut.saveSlideshow()
        XCTAssertFalse(sut.isLoading)
    }
}
