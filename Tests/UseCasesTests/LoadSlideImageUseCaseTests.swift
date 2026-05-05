import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockImageDomainServiceForImage: ImageDomainServiceProtocol, @unchecked Sendable {
    var fetchImageDataResult: Data = Data()
    var fetchImageDataCallCount = 0
    var fetchedLocalIdentifier: String?
    var throwOnFetchImageData = false

    func fetchAllIdentifiers() async throws -> [String] { [] }

    func fetchThumbnailData(localIdentifier: String) async throws -> Data { Data() }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        fetchImageDataCallCount += 1
        fetchedLocalIdentifier = localIdentifier
        if throwOnFetchImageData { throw LoadSlideImageUseCaseTestError.intentional }
        return fetchImageDataResult
    }

    func setDirectory(_ url: URL) async {}

    func filterDroppedFiles(urls: [URL], existingIdentifiers: [String]) -> [String] { [] }
}

private enum LoadSlideImageUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - LoadSlideImageUseCaseTests

final class LoadSlideImageUseCaseTests: XCTestCase {
    private var sut: LoadSlideImageUseCase!
    private var mockDomainService: MockImageDomainServiceForImage!

    override func setUp() {
        super.setUp()
        mockDomainService = MockImageDomainServiceForImage()
        sut = LoadSlideImageUseCase(domainService: mockDomainService)
    }

    override func tearDown() {
        sut = nil
        mockDomainService = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsFetchImageDataOnce() async throws {
        let request = LoadSlideImageRequest(localIdentifier: "some-id")
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.fetchImageDataCallCount, 1)
    }

    func testExecute_forwardsLocalIdentifierToDomainService() async throws {
        let request = LoadSlideImageRequest(localIdentifier: "photo-99")
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.fetchedLocalIdentifier, "photo-99")
    }

    func testExecute_returnsDataFromDomainService() async throws {
        let expected = Data([0x01, 0x02, 0x03])
        mockDomainService.fetchImageDataResult = expected
        let request = LoadSlideImageRequest(localIdentifier: "any-id")
        let result = try await sut.execute(request)
        XCTAssertEqual(result, expected)
    }

    func testExecute_whenDomainServiceThrows_propagatesError() async {
        mockDomainService.throwOnFetchImageData = true
        let request = LoadSlideImageRequest(localIdentifier: "any-id")
        do {
            _ = try await sut.execute(request)
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? LoadSlideImageUseCaseTestError, .intentional)
        }
    }
}
