import XCTest
@testable import TenSlide

final class SlideshowTests: XCTestCase {

    // MARK: - Fixtures

    private var fixedID: UUID!
    private var fixedDate: Date!
    private var fixedSlide: Slide!

    override func setUp() {
        super.setUp()
        fixedID = UUID()
        fixedDate = Date(timeIntervalSince1970: 0)
        fixedSlide = Slide(
            id: UUID(),
            localIdentifier: "asset-1",
            order: 0,
            duration: 5.0,
            title: nil
        )
    }

    override func tearDown() {
        fixedID = nil
        fixedDate = nil
        fixedSlide = nil
        super.tearDown()
    }

    // MARK: - Initialisation

    func testInit_storesID() {
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.id, fixedID)
    }

    func testInit_storesName() {
        let sut = Slideshow(
            id: fixedID,
            name: "Vacation",
            slides: [],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.name, "Vacation")
    }

    func testInit_storesSlides() {
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [fixedSlide],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.slides.count, 1)
    }

    func testInit_storesSlideIdentity() {
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [fixedSlide],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.slides[0].id, fixedSlide.id)
    }

    func testInit_storesConfig() {
        let customConfig = SlideshowConfig(defaultDuration: 10.0, transition: .slide, loop: false)
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: customConfig,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.config, customConfig)
    }

    func testInit_storesCreatedAt() {
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.createdAt, fixedDate)
    }

    // MARK: - Config field

    func testConfig_defaultConfigDuration_isFiveSeconds() {
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.config.defaultDuration, 5.0)
    }

    func testConfig_customTransition_isStoredOnConfig() {
        let customConfig = SlideshowConfig(defaultDuration: 3.0, transition: .dissolve, loop: true)
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: customConfig,
            createdAt: fixedDate
        )
        XCTAssertEqual(sut.config.transition, .dissolve)
    }

    func testConfig_loopDisabled_isStoredOnConfig() {
        let customConfig = SlideshowConfig(defaultDuration: 3.0, transition: .fade, loop: false)
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: customConfig,
            createdAt: fixedDate
        )
        XCTAssertFalse(sut.config.loop)
    }

    // MARK: - Empty slides

    func testInit_emptySlides_countIsZero() {
        let sut = Slideshow(
            id: fixedID,
            name: "My Show",
            slides: [],
            config: .default,
            createdAt: fixedDate
        )
        XCTAssertTrue(sut.slides.isEmpty)
    }

    // MARK: - Equatable

    func testEquality_identicalInstances_areEqual() {
        let lhs = Slideshow(id: fixedID, name: "A", slides: [], config: .default, createdAt: fixedDate)
        let rhs = Slideshow(id: fixedID, name: "A", slides: [], config: .default, createdAt: fixedDate)
        XCTAssertEqual(lhs, rhs)
    }

    func testEquality_differentName_areNotEqual() {
        let lhs = Slideshow(id: fixedID, name: "A", slides: [], config: .default, createdAt: fixedDate)
        let rhs = Slideshow(id: fixedID, name: "B", slides: [], config: .default, createdAt: fixedDate)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEquality_differentID_areNotEqual() {
        let lhs = Slideshow(id: UUID(), name: "A", slides: [], config: .default, createdAt: fixedDate)
        let rhs = Slideshow(id: UUID(), name: "A", slides: [], config: .default, createdAt: fixedDate)
        XCTAssertNotEqual(lhs, rhs)
    }
}
