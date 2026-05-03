import XCTest
@testable import TenSlide

final class TransitionTypeTests: XCTestCase {

    // MARK: - rawValue

    func testRawValue_none_isNone() {
        XCTAssertEqual(TransitionType.none.rawValue, "none")
    }

    func testRawValue_fade_isFade() {
        XCTAssertEqual(TransitionType.fade.rawValue, "fade")
    }

    func testRawValue_slide_isSlide() {
        XCTAssertEqual(TransitionType.slide.rawValue, "slide")
    }

    func testRawValue_dissolve_isDissolve() {
        XCTAssertEqual(TransitionType.dissolve.rawValue, "dissolve")
    }

    // MARK: - rawValue round-trip (init)

    func testInit_rawValueNone_returnsNone() {
        XCTAssertEqual(TransitionType(rawValue: "none"), TransitionType.none)
    }

    func testInit_rawValueFade_returnsFade() {
        XCTAssertEqual(TransitionType(rawValue: "fade"), .fade)
    }

    func testInit_rawValueSlide_returnsSlide() {
        XCTAssertEqual(TransitionType(rawValue: "slide"), .slide)
    }

    func testInit_rawValueDissolve_returnsDissolve() {
        XCTAssertEqual(TransitionType(rawValue: "dissolve"), .dissolve)
    }

    // MARK: - Unknown raw value

    func testInit_unknownRawValue_returnsNil() {
        XCTAssertNil(TransitionType(rawValue: "unknown"))
    }

    func testInit_wrongCaseRawValue_returnsNil() {
        XCTAssertNil(TransitionType(rawValue: "Fade"))
    }

    func testInit_emptyRawValue_returnsNil() {
        XCTAssertNil(TransitionType(rawValue: ""))
    }

    // MARK: - CaseIterable

    func testAllCases_countIsFour() {
        XCTAssertEqual(TransitionType.allCases.count, 4)
    }
}
