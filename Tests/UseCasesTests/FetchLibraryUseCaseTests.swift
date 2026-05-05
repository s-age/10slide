import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockImageDomainServiceForLibrary: ImageDomainServiceProtocol, @unchecked Sendable {
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
    func setDirectory(_ url: URL) async {}
    func filterDroppedFiles(urls: [URL], existingIdentifiers: [String]) -> [String] { [] }
}

private enum FetchLibraryUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - FetchLibraryUseCaseTests

final class FetchLibraryUseCaseTests: XCTestCase {
    private var sut: FetchLibraryUseCase!
    private var mockDomainService: MockImageDomainServiceForLibrary!

    override func setUp() {
        super.setUp()
        mockDomainService = MockImageDomainServiceForLibrary()
        sut = FetchLibraryUseCase(domainService: mockDomainService)
    }

    override func tearDown() {
        sut = nil
        mockDomainService = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsFetchAllIdentifiersOnce() async throws {
        _ = try await sut.execute(FetchLibraryRequest())
        XCTAssertEqual(mockDomainService.fetchAllIdentifiersCallCount, 1)
    }

    func testExecute_returnsIdentifiers_unchanged() async throws {
        mockDomainService.fetchAllIdentifiersResult = ["id-1", "id-2", "id-3"]
        let result = try await sut.execute(FetchLibraryRequest())
        XCTAssertEqual(result, ["id-1", "id-2", "id-3"])
    }

    func testExecute_whenEmpty_returnsEmptyArray() async throws {
        mockDomainService.fetchAllIdentifiersResult = []
        let result = try await sut.execute(FetchLibraryRequest())
        XCTAssertTrue(result.isEmpty)
    }

    func testExecute_whenDomainServiceThrows_propagatesError() async {
        mockDomainService.throwOnFetchAllIdentifiers = true
        do {
            _ = try await sut.execute(FetchLibraryRequest())
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? FetchLibraryUseCaseTestError, .intentional)
        }
    }
}
