import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockConfigDomainServiceForSave: ConfigDomainServiceProtocol, @unchecked Sendable {
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
    private var mockDomainService: MockConfigDomainServiceForSave!

    override func setUp() {
        super.setUp()
        mockDomainService = MockConfigDomainServiceForSave()
        sut = SaveConfigUseCase(domainService: mockDomainService)
    }

    override func tearDown() {
        sut = nil
        mockDomainService = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsDomainServiceSaveOnce() async throws {
        let request = SaveConfigRequest(duration: .five, transition: .fade, loop: true)
        try await sut.execute(request)
        XCTAssertEqual(mockDomainService.saveCallCount, 1)
    }

    func testExecute_forwardsDuration() async throws {
        let request = SaveConfigRequest(duration: .sixty, transition: .fade, loop: true)
        try await sut.execute(request)
        XCTAssertEqual(mockDomainService.savedConfig?.duration, .sixty)
    }

    func testExecute_forwardsTransition() async throws {
        let request = SaveConfigRequest(duration: .five, transition: .slide, loop: true)
        try await sut.execute(request)
        XCTAssertEqual(mockDomainService.savedConfig?.transition, .slide)
    }

    func testExecute_forwardsLoop() async throws {
        let request = SaveConfigRequest(duration: .five, transition: .fade, loop: false)
        try await sut.execute(request)
        XCTAssertEqual(mockDomainService.savedConfig?.loop, false)
    }

    func testExecute_whenDomainServiceThrows_propagatesError() async {
        mockDomainService.throwOnSave = true
        let request = SaveConfigRequest(duration: .five, transition: .fade, loop: true)
        do {
            try await sut.execute(request)
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? SaveConfigUseCaseTestError, .intentional)
        }
    }
}
