import XCTest
@testable import TenSlide

final class SlideshowConfigTests: XCTestCase {

    // MARK: - SlideshowConfig.default

    func testDefault_defaultDurationIsFiveSeconds() {
        XCTAssertEqual(SlideshowConfig.default.defaultDuration, 5.0)
    }

    func testDefault_transitionIsFade() {
        XCTAssertEqual(SlideshowConfig.default.transition, .fade)
    }

    func testDefault_loopIsTrue() {
        XCTAssertTrue(SlideshowConfig.default.loop)
    }

    // MARK: - Custom initialisation

    func testInit_storesDefaultDuration() {
        let sut = SlideshowConfig(defaultDuration: 3.0, transition: .none, loop: false)
        XCTAssertEqual(sut.defaultDuration, 3.0)
    }

    func testInit_storesTransition() {
        let sut = SlideshowConfig(defaultDuration: 3.0, transition: .slide, loop: false)
        XCTAssertEqual(sut.transition, .slide)
    }

    func testInit_storesLoop() {
        let sut = SlideshowConfig(defaultDuration: 3.0, transition: .none, loop: true)
        XCTAssertTrue(sut.loop)
    }

    // MARK: - Equatable

    func testEquality_sameValues_areEqual() {
        let lhs = SlideshowConfig(defaultDuration: 4.0, transition: .dissolve, loop: false)
        let rhs = SlideshowConfig(defaultDuration: 4.0, transition: .dissolve, loop: false)
        XCTAssertEqual(lhs, rhs)
    }

    func testEquality_differentTransition_areNotEqual() {
        let lhs = SlideshowConfig(defaultDuration: 4.0, transition: .fade, loop: true)
        let rhs = SlideshowConfig(defaultDuration: 4.0, transition: .dissolve, loop: true)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEquality_differentDuration_areNotEqual() {
        let lhs = SlideshowConfig(defaultDuration: 4.0, transition: .fade, loop: true)
        let rhs = SlideshowConfig(defaultDuration: 6.0, transition: .fade, loop: true)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEquality_differentLoop_areNotEqual() {
        let lhs = SlideshowConfig(defaultDuration: 4.0, transition: .fade, loop: true)
        let rhs = SlideshowConfig(defaultDuration: 4.0, transition: .fade, loop: false)
        XCTAssertNotEqual(lhs, rhs)
    }
}
