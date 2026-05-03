import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockConfigRepositoryForLoad: ConfigRepositoryProtocol, @unchecked Sendable {
    var loadResult: SlideshowConfig = .default
    var loadCallCount = 0
    var throwOnLoad = false

    func load() async throws -> SlideshowConfig {
        loadCallCount += 1
        if throwOnLoad { throw LoadConfigUseCaseTestError.intentional }
        return loadResult
    }

    func save(_ config: SlideshowConfig) async throws {}
}

private enum LoadConfigUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - LoadConfigUseCaseTests

final class LoadConfigUseCaseTests: XCTestCase {
    private var sut: LoadConfigUseCase!
    private var mockConfigRepository: MockConfigRepositoryForLoad!

    override func setUp() {
        super.setUp()
        mockConfigRepository = MockConfigRepositoryForLoad()
        sut = LoadConfigUseCase(configRepository: mockConfigRepository)
    }

    override func tearDown() {
        sut = nil
        mockConfigRepository = nil
        super.tearDown()
    }

    // MARK: - execute()

    func testExecute_callsConfigRepositoryLoadOnce() async throws {
        _ = try await sut.execute()
        XCTAssertEqual(mockConfigRepository.loadCallCount, 1)
    }

    func testExecute_returnsConfigDefaultDuration() async throws {
        mockConfigRepository.loadResult = SlideshowConfig(defaultDuration: 7.5, transition: .slide, loop: false)
        let result = try await sut.execute()
        XCTAssertEqual(result.defaultDuration, 7.5)
    }

    func testExecute_returnsConfigTransition() async throws {
        mockConfigRepository.loadResult = SlideshowConfig(defaultDuration: 5.0, transition: .dissolve, loop: true)
        let result = try await sut.execute()
        XCTAssertEqual(result.transition, .dissolve)
    }

    func testExecute_returnsConfigLoop() async throws {
        mockConfigRepository.loadResult = SlideshowConfig(defaultDuration: 5.0, transition: .fade, loop: false)
        let result = try await sut.execute()
        XCTAssertFalse(result.loop)
    }

    func testExecute_whenRepositoryThrows_propagatesError() async {
        mockConfigRepository.throwOnLoad = true
        do {
            _ = try await sut.execute()
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? LoadConfigUseCaseTestError, .intentional)
        }
    }
}
