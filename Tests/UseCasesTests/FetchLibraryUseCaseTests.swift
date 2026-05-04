import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockImageRepositoryForLibrary: ImageRepositoryProtocol, @unchecked Sendable {
    var fetchAllIdentifiersResult: [String] = []
    var fetchAllIdentifiersCallCount = 0
    var throwOnFetchAllIdentifiers = false

    func fetchAllIdentifiers() async throws -> [String] {
        fetchAllIdentifiersCallCount += 1
        if throwOnFetchAllIdentifiers { throw FetchLibraryUseCaseTestError.intentional }
        return fetchAllIdentifiersResult
    }

    func fetchImageData(localIdentifier: String) async throws -> Data { Data() }
    func fetchThumbnailData(localIdentifier: String) async throws -> Data { Data() }
}

private enum FetchLibraryUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - FetchLibraryUseCaseTests

final class FetchLibraryUseCaseTests: XCTestCase {
    private var sut: FetchLibraryUseCase!
    private var mockImageRepository: MockImageRepositoryForLibrary!

    override func setUp() {
        super.setUp()
        mockImageRepository = MockImageRepositoryForLibrary()
        sut = FetchLibraryUseCase(imageRepository: mockImageRepository)
    }

    override func tearDown() {
        sut = nil
        mockImageRepository = nil
        super.tearDown()
    }

    // MARK: - execute()

    func testExecute_callsFetchAllIdentifiersOnce() async throws {
        _ = try await sut.execute()
        XCTAssertEqual(mockImageRepository.fetchAllIdentifiersCallCount, 1)
    }

    func testExecute_returnsIdentifiers_unchanged() async throws {
        mockImageRepository.fetchAllIdentifiersResult = ["id-1", "id-2", "id-3"]
        let result = try await sut.execute()
        XCTAssertEqual(result, ["id-1", "id-2", "id-3"])
    }

    func testExecute_whenEmpty_returnsEmptyArray() async throws {
        mockImageRepository.fetchAllIdentifiersResult = []
        let result = try await sut.execute()
        XCTAssertTrue(result.isEmpty)
    }

    func testExecute_whenRepositoryThrows_propagatesError() async {
        mockImageRepository.throwOnFetchAllIdentifiers = true
        do {
            _ = try await sut.execute()
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? FetchLibraryUseCaseTestError, .intentional)
        }
    }
}
