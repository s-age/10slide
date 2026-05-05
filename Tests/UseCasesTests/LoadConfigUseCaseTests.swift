import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockConfigDomainServiceForLoad: ConfigDomainServiceProtocol, @unchecked Sendable {
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
    private var mockDomainService: MockConfigDomainServiceForLoad!

    override func setUp() {
        super.setUp()
        mockDomainService = MockConfigDomainServiceForLoad()
        sut = LoadConfigUseCase(domainService: mockDomainService)
    }

    override func tearDown() {
        sut = nil
        mockDomainService = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsDomainServiceLoadOnce() async throws {
        _ = try await sut.execute(LoadConfigRequest())
        XCTAssertEqual(mockDomainService.loadCallCount, 1)
    }

    func testExecute_returnsConfigDuration() async throws {
        mockDomainService.loadResult = SlideshowConfig(duration: .thirty, transition: .slide, loop: false)
        let result = try await sut.execute(LoadConfigRequest())
        XCTAssertEqual(result.duration, .thirty)
    }

    func testExecute_returnsConfigTransition() async throws {
        mockDomainService.loadResult = SlideshowConfig(duration: .five, transition: .dissolve, loop: true)
        let result = try await sut.execute(LoadConfigRequest())
        XCTAssertEqual(result.transition, .dissolve)
    }

    func testExecute_returnsConfigLoop() async throws {
        mockDomainService.loadResult = SlideshowConfig(duration: .five, transition: .fade, loop: false)
        let result = try await sut.execute(LoadConfigRequest())
        XCTAssertFalse(result.loop)
    }

    func testExecute_whenDomainServiceThrows_propagatesError() async {
        mockDomainService.throwOnLoad = true
        do {
            _ = try await sut.execute(LoadConfigRequest())
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? LoadConfigUseCaseTestError, .intentional)
        }
    }
}
