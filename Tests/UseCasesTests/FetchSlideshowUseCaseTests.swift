import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockSlideshowDomainServiceForFetch: SlideshowDomainServiceProtocol, @unchecked Sendable {
    var fetchResult: Slideshow?
    var fetchCallCount = 0
    var fetchedID: UUID?
    var throwOnFetch = false

    func fetchAll() async throws -> [Slideshow] { [] }

    func fetch(id: UUID) async throws -> Slideshow? {
        fetchCallCount += 1
        fetchedID = id
        if throwOnFetch { throw FetchSlideshowUseCaseTestError.intentional }
        return fetchResult
    }

    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        Slideshow(id: UUID(), name: name, slides: [], config: config, createdAt: Date())
    }

    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        Slideshow(id: id, name: name, slides: [], config: .default, createdAt: Date())
    }

    func delete(id: UUID) async throws {}
}

private enum FetchSlideshowUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - FetchSlideshowUseCaseTests

final class FetchSlideshowUseCaseTests: XCTestCase {
    private var sut: FetchSlideshowUseCase!
    private var mockDomainService: MockSlideshowDomainServiceForFetch!

    override func setUp() {
        super.setUp()
        mockDomainService = MockSlideshowDomainServiceForFetch()
        sut = FetchSlideshowUseCase(domainService: mockDomainService)
    }

    override func tearDown() {
        sut = nil
        mockDomainService = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsDomainServiceFetchOnce() async throws {
        let request = FetchSlideshowRequest(id: UUID())
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.fetchCallCount, 1)
    }

    func testExecute_forwardsIDToDomainService() async throws {
        let id = UUID()
        let request = FetchSlideshowRequest(id: id)
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.fetchedID, id)
    }

    func testExecute_whenNotFound_returnsNil() async throws {
        mockDomainService.fetchResult = nil
        let request = FetchSlideshowRequest(id: UUID())
        let result = try await sut.execute(request)
        XCTAssertNil(result)
    }

    func testExecute_returnsCorrectSlideshowID() async throws {
        let expected = makeSlideshow()
        mockDomainService.fetchResult = expected
        let request = FetchSlideshowRequest(id: expected.id)
        let result = try await sut.execute(request)
        XCTAssertEqual(result?.id, expected.id)
    }

    func testExecute_whenDomainServiceThrows_propagatesError() async {
        mockDomainService.throwOnFetch = true
        let request = FetchSlideshowRequest(id: UUID())
        do {
            _ = try await sut.execute(request)
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? FetchSlideshowUseCaseTestError, .intentional)
        }
    }

    // MARK: - Helpers

    private func makeSlideshow(
        id: UUID = UUID(),
        name: String = "Test Slideshow"
    ) -> Slideshow {
        Slideshow(
            id: id,
            name: name,
            slides: [],
            config: .default,
            createdAt: Date()
        )
    }
}
