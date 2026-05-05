import XCTest
@testable import TenSlide

final class ConfigStoreTests: XCTestCase {
    private var sut: ConfigStore!
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        fileURL = tempDir.appendingPathComponent("config.yml")
        sut = ConfigStore(fileURL: fileURL)
    }

    override func tearDown() async throws {
        sut = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        fileURL = nil
        try await super.tearDown()
    }

    // MARK: - load (file absent -> nil)

    func testLoad_whenFileDoesNotExist_returnsNil() async throws {
        let dto = try await sut.load()
        XCTAssertNil(dto)
    }

    // MARK: - save -> load round-trip

    func testSaveThenLoad_roundTrip_returnsSameDuration() async throws {
        let original = ConfigDTO(duration: "30", transition: "fade", loop: true)
        try await sut.save(original)
        let loaded = try await sut.load()
        XCTAssertEqual(loaded?.duration, "30")
    }

    func testSaveThenLoad_roundTrip_returnsSameLoop() async throws {
        let original = ConfigDTO(duration: "5", transition: "fade", loop: false)
        try await sut.save(original)
        let loaded = try await sut.load()
        XCTAssertEqual(loaded?.loop, false)
    }

    // MARK: - transition stored as plain String

    func testSaveThenLoad_roundTrip_returnsSameTransitionString() async throws {
        let original = ConfigDTO(duration: "5", transition: "slide", loop: true)
        try await sut.save(original)
        let loaded = try await sut.load()
        XCTAssertEqual(loaded?.transition, "slide")
    }

    func testSaveThenLoad_arbitraryTransitionString_roundTripsWithoutError() async throws {
        let original = ConfigDTO(duration: "5", transition: "none", loop: true)
        try await sut.save(original)
        let loaded = try await sut.load()
        XCTAssertEqual(loaded?.transition, "none")
    }

    // MARK: - load (malformed file -> throws)

    func testLoad_whenFileContainsInvalidYAML_throws() async {
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? "not: valid: yaml: [[[".write(to: fileURL, atomically: true, encoding: .utf8)
        do {
            _ = try await sut.load()
            XCTFail("Expected load() to throw for malformed YAML")
        } catch {
            // expected
        }
    }
}
