import XCTest
@testable import TenSlide

// MARK: - Error

private enum SlideshowPlayerTestError: Error {
    case intentional
}

// MARK: - Mock: LoadSlideImageUseCase

final class MockLoadSlideImageUseCase: LoadSlideImageUseCaseProtocol, @unchecked Sendable {
    // Minimal valid 1x1 pixel PNG
    // swiftlint:disable:next line_length
    var executeResult: Data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")!
    var executeCallCount = 0
    var throwOnExecute = false

    func execute(_ request: LoadSlideImageRequest) async throws -> Data {
        executeCallCount += 1
        if throwOnExecute { throw SlideshowPlayerTestError.intentional }
        return executeResult
    }
}

// MARK: - Mock: UpdateSlideshowConfigUseCase

final class MockUpdateSlideshowConfigUseCase: UpdateSlideshowConfigUseCaseProtocol, @unchecked Sendable {
    var executeCallCount = 0
    var lastRequest: UpdateSlideshowConfigRequest?
    var executeResult: SlideshowResponse?

    func execute(_ request: UpdateSlideshowConfigRequest) async throws -> SlideshowResponse {
        executeCallCount += 1
        lastRequest = request
        if let result = executeResult {
            return result
        }
        return SlideshowResponse(
            id: request.slideshowID,
            name: "Updated",
            slides: [],
            config: SlideshowConfigResponse(
                duration: request.duration,
                transition: request.transition,
                loop: request.loop
            ),
            createdAt: Date()
        )
    }
}

// MARK: - Mock: AdvanceSlideUseCase

final class MockAdvanceSlideUseCase: AdvanceSlideUseCaseProtocol, @unchecked Sendable {
    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        try request.validate()
        let next = request.currentIndex + 1
        if next < request.totalSlides {
            return next
        } else if request.loop {
            return 0
        }
        return nil
    }

    func executePrevious(_ request: PreviousSlideRequest) throws -> Int? {
        try request.validate()
        let prev = request.currentIndex - 1
        if prev >= 0 {
            return prev
        } else if request.loop {
            return request.totalSlides - 1
        }
        return nil
    }
}

// MARK: - SlideshowPlayerViewModelTests

@MainActor
final class SlideshowPlayerViewModelTests: XCTestCase {
    private var sut: SlideshowPlayerViewModel!
    private var mockLoadSlideImage: MockLoadSlideImageUseCase!
    private var mockUpdateSlideshowConfig: MockUpdateSlideshowConfigUseCase!
    private var mockAdvanceSlide: MockAdvanceSlideUseCase!

    override func setUp() {
        super.setUp()
        mockLoadSlideImage = MockLoadSlideImageUseCase()
        mockUpdateSlideshowConfig = MockUpdateSlideshowConfigUseCase()
        mockAdvanceSlide = MockAdvanceSlideUseCase()
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(
                slides: [
                    Self.makeSlide(identifier: "a", order: 0),
                    Self.makeSlide(identifier: "b", order: 1),
                    Self.makeSlide(identifier: "c", order: 2)
                ],
                loop: false
            ),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide,
            filmstripHideDuration: .milliseconds(50)
        )
    }

    override func tearDown() {
        sut.pause()
        sut = nil
        mockLoadSlideImage = nil
        mockUpdateSlideshowConfig = nil
        mockAdvanceSlide = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private static func makeSlide(
        identifier: String,
        order: Int,
        duration: TimeInterval = 60.0
    ) -> SlideResponse {
        SlideResponse(id: UUID(), localIdentifier: identifier, order: order, duration: duration, title: nil)
    }

    private static func makeSlideshow(slides: [SlideResponse], loop: Bool) -> SlideshowResponse {
        SlideshowResponse(
            id: UUID(),
            name: "Test Slideshow",
            slides: slides,
            config: SlideshowConfigResponse(duration: .five, transition: .fade, loop: loop),
            createdAt: Date()
        )
    }

    // MARK: - play()

    func testPlay_setsIsPlayingToTrue() {
        sut.play()
        XCTAssertTrue(sut.isPlaying)
    }

    func testPlay_setsShowFilmstripToTrue() {
        sut.play()
        XCTAssertTrue(sut.showFilmstrip)
    }

    func testPlay_withEmptySlides_doesNotSetIsPlayingToTrue() {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        sut.play()
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - pause()

    func testPause_setsIsPlayingToFalse() {
        sut.play()
        sut.pause()
        XCTAssertFalse(sut.isPlaying)
    }

    func testPause_setsShowFilmstripToTrue() {
        sut.play()
        sut.pause()
        XCTAssertTrue(sut.showFilmstrip)
    }

    // MARK: - next()

    func testNext_advancesCurrentIndex() async {
        await sut.next()
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func testNext_atLastSlide_noLoop_setsIsPlayingToFalse() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [Self.makeSlide(identifier: "only", order: 0)], loop: false),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        sut.play()
        await sut.next()
        XCTAssertFalse(sut.isPlaying)
    }

    func testNext_atLastSlide_noLoop_currentIndexUnchanged() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [Self.makeSlide(identifier: "only", order: 0)], loop: false),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        await sut.next()
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testNext_atLastSlide_withLoop_wrapsToZero() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(
                slides: [
                    Self.makeSlide(identifier: "a", order: 0),
                    Self.makeSlide(identifier: "b", order: 1)
                ],
                loop: true
            ),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        await sut.next()   // 0 -> 1
        await sut.next()   // 1 -> wraps to 0
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testNext_withEmptySlides_currentIndexRemainsZero() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        await sut.next()
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - previous()

    func testPrevious_decrementsCurrentIndex() async {
        await sut.next()      // currentIndex -> 1
        await sut.previous()  // currentIndex -> 0
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testPrevious_atFirstSlide_noLoop_clampedAtZero() async {
        await sut.previous()
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testPrevious_atFirstSlide_withLoop_wrapsToLastIndex() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(
                slides: [
                    Self.makeSlide(identifier: "a", order: 0),
                    Self.makeSlide(identifier: "b", order: 1)
                ],
                loop: true
            ),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        await sut.previous()
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func testPrevious_withEmptySlides_currentIndexRemainsZero() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        await sut.previous()
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - jumpTo(index:)

    func testJumpTo_setsCurrentIndex() async {
        await sut.jumpTo(index: 2)
        XCTAssertEqual(sut.currentIndex, 2)
    }

    func testJumpTo_fromNonZero_setsCurrentIndexToTarget() async {
        await sut.next()           // currentIndex -> 1
        await sut.jumpTo(index: 0)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testJumpTo_negativeIndex_doesNotChangeCurrentIndex() async {
        await sut.jumpTo(index: -1)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testJumpTo_outOfBoundsIndex_doesNotChangeCurrentIndex() async {
        await sut.jumpTo(index: 99)
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - loadCurrentImage()

    func testLoadCurrentImage_whenSlideExists_setsCurrentNSImage() async {
        await sut.loadCurrentImage()
        XCTAssertNotNil(sut.currentNSImage)
    }

    func testLoadCurrentImage_callsUseCaseOnce() async {
        await sut.loadCurrentImage()
        XCTAssertEqual(mockLoadSlideImage.executeCallCount, 1)
    }

    func testLoadCurrentImage_withEmptySlides_setsCurrentNSImageToNil() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide
        )
        await sut.loadCurrentImage()
        XCTAssertNil(sut.currentNSImage)
    }

    func testLoadCurrentImage_whenUseCaseThrows_setsCurrentNSImageToNil() async {
        mockLoadSlideImage.throwOnExecute = true
        await sut.loadCurrentImage()
        XCTAssertNil(sut.currentNSImage)
    }

    // MARK: - updateDuration()

    func testUpdateDuration_callsUseCaseOnce() async {
        await sut.updateDuration(.ten)
        XCTAssertEqual(mockUpdateSlideshowConfig.executeCallCount, 1)
    }

    func testUpdateDuration_updatesSlideshowConfig() async {
        await sut.updateDuration(.ten)
        XCTAssertEqual(sut.slideshow.config.duration, .ten)
    }

    func testUpdateDuration_whilePlaying_restartsPlayback() async {
        sut.play()
        await sut.updateDuration(.thirty)
        XCTAssertTrue(sut.isPlaying)
    }

    // MARK: - updateTransition()

    func testUpdateTransition_callsUseCaseOnce() async {
        await sut.updateTransition(.slide)
        XCTAssertEqual(mockUpdateSlideshowConfig.executeCallCount, 1)
    }

    func testUpdateTransition_updatesSlideshowConfig() async {
        await sut.updateTransition(.slide)
        XCTAssertEqual(sut.slideshow.config.transition, .slide)
    }

    // MARK: - userDidInteract()

    func testUserDidInteract_setsShowFilmstripToTrue() {
        sut.userDidInteract()
        XCTAssertTrue(sut.showFilmstrip)
    }

    // MARK: - showFilmstripOverlay()

    func testShowFilmstripOverlay_setsShowFilmstripToTrue() {
        sut.showFilmstripOverlay()
        XCTAssertTrue(sut.showFilmstrip)
    }

    func testShowFilmstripOverlay_whileNotPlaying_showFilmstripRemainsTrue() async throws {
        sut.showFilmstripOverlay()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showFilmstrip)
    }

    func testShowFilmstripOverlay_whilePlaying_hidesAfterHideDuration() async throws {
        sut.play()
        XCTAssertTrue(sut.showFilmstrip)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(sut.showFilmstrip)
    }
}
