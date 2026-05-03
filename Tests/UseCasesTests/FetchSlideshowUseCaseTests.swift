import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockSlideshowRepositoryForFetch: SlideshowRepositoryProtocol, @unchecked Sendable {
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

    func save(_ slideshow: Slideshow) async throws {}

    func delete(id: UUID) async throws {}
}

private enum FetchSlideshowUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - FetchSlideshowUseCaseTests

final class FetchSlideshowUseCaseTests: XCTestCase {
    private var sut: FetchSlideshowUseCase!
    private var mockSlideshowRepository: MockSlideshowRepositoryForFetch!

    override func setUp() {
        super.setUp()
        mockSlideshowRepository = MockSlideshowRepositoryForFetch()
        sut = FetchSlideshowUseCase(slideshowRepository: mockSlideshowRepository)
    }

    override func tearDown() {
        sut = nil
        mockSlideshowRepository = nil
        super.tearDown()
    }

    // MARK: - execute(id:)

    func testExecute_callsRepositoryFetchOnce() async throws {
        _ = try await sut.execute(id: UUID())
        XCTAssertEqual(mockSlideshowRepository.fetchCallCount, 1)
    }

    func testExecute_forwardsIDToRepository() async throws {
        let id = UUID()
        _ = try await sut.execute(id: id)
        XCTAssertEqual(mockSlideshowRepository.fetchedID, id)
    }

    func testExecute_whenNotFound_returnsNil() async throws {
        mockSlideshowRepository.fetchResult = nil
        let result = try await sut.execute(id: UUID())
        XCTAssertNil(result)
    }

    func testExecute_returnsCorrectSlideshowID() async throws {
        let expected = makeSlideshow()
        mockSlideshowRepository.fetchResult = expected
        let result = try await sut.execute(id: expected.id)
        XCTAssertEqual(result?.id, expected.id)
    }

    func testExecute_whenRepositoryThrows_propagatesError() async {
        mockSlideshowRepository.throwOnFetch = true
        do {
            _ = try await sut.execute(id: UUID())
            XCTFail("Expected execute(id:) to throw")
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
