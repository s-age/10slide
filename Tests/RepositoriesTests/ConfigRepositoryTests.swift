import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockConfigDataSource: ConfigDataSourceProtocol, @unchecked Sendable {
    var loadResult: ConfigDTO = ConfigDTO(duration: "5", transition: "fade", loop: true)
    var loadCallCount = 0
    var loadError: Error?

    var saveCallCount = 0
    var savedDTO: ConfigDTO?
    var saveError: Error?

    func load() async throws -> ConfigDTO {
        loadCallCount += 1
        if let error = loadError { throw error }
        return loadResult
    }

    func save(_ dto: ConfigDTO) async throws {
        saveCallCount += 1
        savedDTO = dto
        if let error = saveError { throw error }
    }
}

// MARK: - ConfigRepositoryTests

final class ConfigRepositoryTests: XCTestCase {
    private var sut: ConfigRepository!
    private var mockDataSource: MockConfigDataSource!

    override func setUp() {
        super.setUp()
        mockDataSource = MockConfigDataSource()
        sut = ConfigRepository(configDataSource: mockDataSource)
    }

    override func tearDown() {
        sut = nil
        mockDataSource = nil
        super.tearDown()
    }

    // MARK: - load()

    func testLoad_callsDataSourceOnce() async throws {
        _ = try await sut.load()
        XCTAssertEqual(mockDataSource.loadCallCount, 1)
    }

    func testLoad_mapsKnownDuration_thirty() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "30", transition: "fade", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.duration, .thirty)
    }

    func testLoad_unknownDurationRawValue_fallsBackToFive() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "99", transition: "fade", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.duration, .five)
    }

    func testLoad_mapsKnownTransition_fade() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "fade", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.transition, .fade)
    }

    func testLoad_mapsKnownTransition_slide() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "slide", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.transition, .slide)
    }

    func testLoad_mapsKnownTransition_dissolve() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "dissolve", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.transition, .dissolve)
    }

    func testLoad_mapsKnownTransition_none() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "none", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.transition, .none)
    }

    func testLoad_unknownTransitionRawValue_fallsBackToFade() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "sparkle", loop: true)
        let config = try await sut.load()
        XCTAssertEqual(config.transition, .fade)
    }

    func testLoad_mapsLoopTrue() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "fade", loop: true)
        let config = try await sut.load()
        XCTAssertTrue(config.loop)
    }

    func testLoad_mapsLoopFalse() async throws {
        mockDataSource.loadResult = ConfigDTO(duration: "5", transition: "fade", loop: false)
        let config = try await sut.load()
        XCTAssertFalse(config.loop)
    }

    func testLoad_whenDataSourceThrows_propagatesError() async {
        struct LoadError: Error {}
        mockDataSource.loadError = LoadError()
        do {
            _ = try await sut.load()
            XCTFail("Expected load() to throw")
        } catch {
            // error was propagated correctly
        }
    }

    // MARK: - save()

    func testSave_callsDataSourceOnce() async throws {
        let config = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.saveCallCount, 1)
    }

    func testSave_encodesDurationAsRawValue() async throws {
        let config = SlideshowConfig(duration: .thirty, transition: .fade, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.duration, "30")
    }

    func testSave_encodesDuration_manual() async throws {
        let config = SlideshowConfig(duration: .manual, transition: .fade, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.duration, "manual")
    }

    func testSave_encodesTransitionAsRawValue_fade() async throws {
        let config = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.transition, "fade")
    }

    func testSave_encodesTransitionAsRawValue_dissolve() async throws {
        let config = SlideshowConfig(duration: .five, transition: .dissolve, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.transition, "dissolve")
    }

    func testSave_encodesTransitionAsRawValue_slide() async throws {
        let config = SlideshowConfig(duration: .five, transition: .slide, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.transition, "slide")
    }

    func testSave_encodesTransitionAsRawValue_none() async throws {
        let config = SlideshowConfig(duration: .five, transition: .none, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.transition, "none")
    }

    func testSave_encodesLoopTrue() async throws {
        let config = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.loop, true)
    }

    func testSave_encodesLoopFalse() async throws {
        let config = SlideshowConfig(duration: .five, transition: .fade, loop: false)
        try await sut.save(config)
        XCTAssertEqual(mockDataSource.savedDTO?.loop, false)
    }

    func testSave_whenDataSourceThrows_propagatesError() async {
        struct SaveError: Error {}
        mockDataSource.saveError = SaveError()
        let config = SlideshowConfig(duration: .five, transition: .fade, loop: true)
        do {
            try await sut.save(config)
            XCTFail("Expected save() to throw")
        } catch {
            // error was propagated correctly
        }
    }
}
