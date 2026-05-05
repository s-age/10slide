import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockImageDataSource: ImageDataSourceProtocol, @unchecked Sendable {
    var fetchAllIdentifiersResult: [String] = []
    var fetchAllIdentifiersCallCount = 0
    var throwOnFetchAllIdentifiers = false

    var fetchImageResult: ImageDTO?
    var fetchImageCallCount = 0
    var fetchedLocalIdentifier: String?
    var throwOnFetchImage = false

    var supportedExtensions: Set<String> = ["jpg", "png"]

    func fetchAllIdentifiers() async throws -> [String] {
        fetchAllIdentifiersCallCount += 1
        if throwOnFetchAllIdentifiers { throw ImageRepoTestError.intentional }
        return fetchAllIdentifiersResult
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        fetchImageCallCount += 1
        fetchedLocalIdentifier = localIdentifier
        if throwOnFetchImage { throw ImageRepoTestError.intentional }
        return fetchImageResult ?? ImageDTO(localIdentifier: localIdentifier, data: Data(), creationDate: nil)
    }

    func fetchThumbnail(localIdentifier: String) async throws -> Data { Data() }

    func setDirectory(_ url: URL) {}
}

private enum ImageRepoTestError: Error {
    case intentional
}

// MARK: - ImageRepositoryTests

final class ImageRepositoryTests: XCTestCase {
    private var sut: ImageRepository!
    private var mockDataSource: MockImageDataSource!

    override func setUp() {
        super.setUp()
        mockDataSource = MockImageDataSource()
        sut = ImageRepository(imageDataSource: mockDataSource)
    }

    override func tearDown() {
        sut = nil
        mockDataSource = nil
        super.tearDown()
    }

    // MARK: - fetchAllIdentifiers()

    func testFetchAllIdentifiers_callsDataSourceOnce() async throws {
        _ = try await sut.fetchAllIdentifiers()
        XCTAssertEqual(mockDataSource.fetchAllIdentifiersCallCount, 1)
    }

    func testFetchAllIdentifiers_onEmptyDataSource_returnsEmptyArray() async throws {
        mockDataSource.fetchAllIdentifiersResult = []
        let result = try await sut.fetchAllIdentifiers()
        XCTAssertTrue(result.isEmpty)
    }

    func testFetchAllIdentifiers_returnsIdentifiersFromDataSource() async throws {
        mockDataSource.fetchAllIdentifiersResult = ["abc", "def", "ghi"]
        let result = try await sut.fetchAllIdentifiers()
        XCTAssertEqual(result, ["abc", "def", "ghi"])
    }

    func testFetchAllIdentifiers_returnsCorrectCount() async throws {
        mockDataSource.fetchAllIdentifiersResult = ["id1", "id2", "id3"]
        let result = try await sut.fetchAllIdentifiers()
        XCTAssertEqual(result.count, 3)
    }

    func testFetchAllIdentifiers_preservesIdentifierValues() async throws {
        let expected = "photos://local/asset/ABCD-1234"
        mockDataSource.fetchAllIdentifiersResult = [expected]
        let result = try await sut.fetchAllIdentifiers()
        XCTAssertEqual(result[0], expected)
    }

    func testFetchAllIdentifiers_whenDataSourceThrows_propagatesError() async {
        mockDataSource.throwOnFetchAllIdentifiers = true
        do {
            _ = try await sut.fetchAllIdentifiers()
            XCTFail("Expected fetchAllIdentifiers() to throw")
        } catch {
            // error was propagated correctly
        }
    }

    // MARK: - fetchImageData(localIdentifier:)

    func testFetchImageData_callsDataSourceOnce() async throws {
        mockDataSource.fetchImageResult = ImageDTO(localIdentifier: "x", data: Data([1, 2, 3]), creationDate: nil)
        _ = try await sut.fetchImageData(localIdentifier: "x")
        XCTAssertEqual(mockDataSource.fetchImageCallCount, 1)
    }

    func testFetchImageData_forwardsLocalIdentifierToDataSource() async throws {
        mockDataSource.fetchImageResult = ImageDTO(localIdentifier: "test-id", data: Data(), creationDate: nil)
        _ = try await sut.fetchImageData(localIdentifier: "test-id")
        XCTAssertEqual(mockDataSource.fetchedLocalIdentifier, "test-id")
    }

    func testFetchImageData_forwardsLocalIdentifierUnchanged_withSpecialChars() async throws {
        let identifier = "photos://local/asset/ABCD-1234-EFGH-5678"
        mockDataSource.fetchImageResult = ImageDTO(localIdentifier: identifier, data: Data(), creationDate: nil)
        _ = try await sut.fetchImageData(localIdentifier: identifier)
        XCTAssertEqual(mockDataSource.fetchedLocalIdentifier, identifier)
    }

    func testFetchImageData_returnsDtoData() async throws {
        let expectedData = Data([10, 20, 30, 40])
        mockDataSource.fetchImageResult = ImageDTO(localIdentifier: "x", data: expectedData, creationDate: nil)
        let result = try await sut.fetchImageData(localIdentifier: "x")
        XCTAssertEqual(result, expectedData)
    }

    func testFetchImageData_doesNotReturnEmptyDataWhenDtoHasBytes() async throws {
        let nonEmpty = Data([0xFF, 0xD8, 0xFF])
        mockDataSource.fetchImageResult = ImageDTO(localIdentifier: "x", data: nonEmpty, creationDate: nil)
        let result = try await sut.fetchImageData(localIdentifier: "x")
        XCTAssertFalse(result.isEmpty)
    }

    func testFetchImageData_whenDataSourceThrows_propagatesError() async {
        mockDataSource.throwOnFetchImage = true
        do {
            _ = try await sut.fetchImageData(localIdentifier: "any")
            XCTFail("Expected fetchImageData(localIdentifier:) to throw")
        } catch {
            // error was propagated correctly
        }
    }
}
