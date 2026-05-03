import XCTest
@testable import TenSlide

// MARK: - Error

private enum SlideshowPlayerTestError: Error {
    case intentional
}

// MARK: - Mock: LoadSlideImageUseCase

final class MockLoadSlideImageUseCase: LoadSlideImageUseCaseProtocol, @unchecked Sendable {
    var executeResult: Data = Data([0xFF])
    var executeCallCount = 0
    var throwOnExecute = false

    func execute(localIdentifier: String) async throws -> Data {
        executeCallCount += 1
        if throwOnExecute { throw SlideshowPlayerTestError.intentional }
        return executeResult
    }
}

// MARK: - SlideshowPlayerViewModelTests

@MainActor
final class SlideshowPlayerViewModelTests: XCTestCase {
    private var sut: SlideshowPlayerViewModel!
    private var mockLoadSlideImage: MockLoadSlideImageUseCase!

    override func setUp() {
        super.setUp()
        mockLoadSlideImage = MockLoadSlideImageUseCase()
        // Default: 3-slide show, no loop, 60 s per slide so the auto-advance timer never fires.
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
            filmstripHideDuration: .milliseconds(50)
        )
    }

    override func tearDown() {
        sut.pause()   // cancel any in-flight Tasks before releasing
        sut = nil
        mockLoadSlideImage = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private static func makeSlide(
        identifier: String,
        order: Int,
        duration: TimeInterval = 60.0
    ) -> Slide {
        Slide(id: UUID(), localIdentifier: identifier, order: order, duration: duration, title: nil)
    }

    private static func makeSlideshow(slides: [Slide], loop: Bool) -> Slideshow {
        Slideshow(
            id: UUID(),
            name: "Test Slideshow",
            slides: slides,
            config: SlideshowConfig(defaultDuration: 5.0, transition: .fade, loop: loop),
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
            loadSlideImage: mockLoadSlideImage
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
            loadSlideImage: mockLoadSlideImage
        )
        sut.play()
        await sut.next()
        XCTAssertFalse(sut.isPlaying)
    }

    func testNext_atLastSlide_noLoop_currentIndexUnchanged() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [Self.makeSlide(identifier: "only", order: 0)], loop: false),
            loadSlideImage: mockLoadSlideImage
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
            loadSlideImage: mockLoadSlideImage
        )
        await sut.next()   // 0 → 1
        await sut.next()   // 1 → wraps to 0
        XCTAssertEqual(sut.currentIndex, 0)
    }

    func testNext_withEmptySlides_currentIndexRemainsZero() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage
        )
        await sut.next()
        XCTAssertEqual(sut.currentIndex, 0)
    }

    // MARK: - previous()

    func testPrevious_decrementsCurrentIndex() async {
        await sut.next()      // currentIndex → 1
        await sut.previous()  // currentIndex → 0
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
            loadSlideImage: mockLoadSlideImage
        )
        await sut.previous()
        XCTAssertEqual(sut.currentIndex, 1)
    }

    func testPrevious_withEmptySlides_currentIndexRemainsZero() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage
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
        await sut.next()           // currentIndex → 1
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

    func testLoadCurrentImage_whenSlideExists_setsCurrentImageData() async {
        let data = Data([0x01, 0x02, 0x03])
        mockLoadSlideImage.executeResult = data
        await sut.loadCurrentImage()
        XCTAssertEqual(sut.currentImageData, data)
    }

    func testLoadCurrentImage_callsUseCaseOnce() async {
        await sut.loadCurrentImage()
        XCTAssertEqual(mockLoadSlideImage.executeCallCount, 1)
    }

    func testLoadCurrentImage_withEmptySlides_setsCurrentImageDataToNil() async {
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(slides: [], loop: false),
            loadSlideImage: mockLoadSlideImage
        )
        await sut.loadCurrentImage()
        XCTAssertNil(sut.currentImageData)
    }

    func testLoadCurrentImage_whenUseCaseThrows_setsCurrentImageDataToNil() async {
        mockLoadSlideImage.throwOnExecute = true
        await sut.loadCurrentImage()
        XCTAssertNil(sut.currentImageData)
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
        // When not playing the hide-timer must NOT start; showFilmstrip stays true indefinitely.
        sut.showFilmstripOverlay()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showFilmstrip)
    }

    func testShowFilmstripOverlay_whilePlaying_hidesAfterHideDuration() async throws {
        // setUp passes filmstripHideDuration: .milliseconds(50), so we only need to wait 100 ms.
        sut.play()
        XCTAssertTrue(sut.showFilmstrip)           // immediately after play()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(sut.showFilmstrip)
    }
}
