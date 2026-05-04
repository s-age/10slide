import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockConfigRepositoryForSave: ConfigRepositoryProtocol, @unchecked Sendable {
    var saveCallCount = 0
    var savedConfig: SlideshowConfig?
    var throwOnSave = false

    func load() async throws -> SlideshowConfig { .default }

    func save(_ config: SlideshowConfig) async throws {
        saveCallCount += 1
        savedConfig = config
        if throwOnSave { throw SaveConfigUseCaseTestError.intentional }
    }
}

private enum SaveConfigUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - SaveConfigUseCaseTests

final class SaveConfigUseCaseTests: XCTestCase {
    private var sut: SaveConfigUseCase!
    private var mockConfigRepository: MockConfigRepositoryForSave!

    override func setUp() {
        super.setUp()
        mockConfigRepository = MockConfigRepositoryForSave()
        sut = SaveConfigUseCase(configRepository: mockConfigRepository)
    }

    override func tearDown() {
        sut = nil
        mockConfigRepository = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsConfigRepositorySaveOnce() async throws {
        try await sut.execute(.default)
        XCTAssertEqual(mockConfigRepository.saveCallCount, 1)
    }

    func testExecute_forwardsConfigDuration() async throws {
        let config = SlideshowConfig(duration: .sixty, transition: .fade, loop: true)
        try await sut.execute(config)
        XCTAssertEqual(mockConfigRepository.savedConfig?.duration, .sixty)
    }

    func testExecute_forwardsConfigTransition() async throws {
        let config = SlideshowConfig(duration: .five, transition: .slide, loop: true)
        try await sut.execute(config)
        XCTAssertEqual(mockConfigRepository.savedConfig?.transition, .slide)
    }

    func testExecute_forwardsConfigLoop() async throws {
        let config = SlideshowConfig(duration: .five, transition: .fade, loop: false)
        try await sut.execute(config)
        XCTAssertEqual(mockConfigRepository.savedConfig?.loop, false)
    }

    func testExecute_whenRepositoryThrows_propagatesError() async {
        mockConfigRepository.throwOnSave = true
        do {
            try await sut.execute(.default)
            XCTFail("Expected execute(_:) to throw")
        } catch {
            XCTAssertEqual(error as? SaveConfigUseCaseTestError, .intentional)
        }
    }
}
