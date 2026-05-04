import XCTest
@testable import TenSlide

final class SlideshowConfigTests: XCTestCase {

    // MARK: - SlideshowConfig.default

    func testDefault_durationIsFive() {
        XCTAssertEqual(SlideshowConfig.default.duration, .five)
    }

    func testDefault_transitionIsFade() {
        XCTAssertEqual(SlideshowConfig.default.transition, .fade)
    }

    func testDefault_loopIsTrue() {
        XCTAssertTrue(SlideshowConfig.default.loop)
    }

    // MARK: - Custom initialisation

    func testInit_storesDuration() {
        let sut = SlideshowConfig(duration: .thirty, transition: .none, loop: false)
        XCTAssertEqual(sut.duration, .thirty)
    }

    func testInit_storesTransition() {
        let sut = SlideshowConfig(duration: .ten, transition: .slide, loop: false)
        XCTAssertEqual(sut.transition, .slide)
    }

    func testInit_storesLoop() {
        let sut = SlideshowConfig(duration: .ten, transition: .none, loop: true)
        XCTAssertTrue(sut.loop)
    }

    // MARK: - Equatable

    func testEquality_sameValues_areEqual() {
        let lhs = SlideshowConfig(duration: .fifteen, transition: .dissolve, loop: false)
        let rhs = SlideshowConfig(duration: .fifteen, transition: .dissolve, loop: false)
        XCTAssertEqual(lhs, rhs)
    }

    func testEquality_differentTransition_areNotEqual() {
        let lhs = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        let rhs = SlideshowConfig(duration: .five, transition: .dissolve, loop: true)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEquality_differentDuration_areNotEqual() {
        let lhs = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        let rhs = SlideshowConfig(duration: .thirty, transition: .fade, loop: true)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testEquality_differentLoop_areNotEqual() {
        let lhs = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        let rhs = SlideshowConfig(duration: .five, transition: .fade, loop: false)
        XCTAssertNotEqual(lhs, rhs)
    }
}
