import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockImageRepositoryForImage: ImageRepositoryProtocol, @unchecked Sendable {
    var fetchImageDataResult: Data = Data()
    var fetchImageDataCallCount = 0
    var fetchedLocalIdentifier: String?
    var throwOnFetchImageData = false

    func fetchAllIdentifiers() async throws -> [String] { [] }

    func fetchImageData(localIdentifier: String) async throws -> Data {
        fetchImageDataCallCount += 1
        fetchedLocalIdentifier = localIdentifier
        if throwOnFetchImageData { throw LoadSlideImageUseCaseTestError.intentional }
        return fetchImageDataResult
    }
}

private enum LoadSlideImageUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - LoadSlideImageUseCaseTests

final class LoadSlideImageUseCaseTests: XCTestCase {
    private var sut: LoadSlideImageUseCase!
    private var mockImageRepository: MockImageRepositoryForImage!

    override func setUp() {
        super.setUp()
        mockImageRepository = MockImageRepositoryForImage()
        sut = LoadSlideImageUseCase(imageRepository: mockImageRepository)
    }

    override func tearDown() {
        sut = nil
        mockImageRepository = nil
        super.tearDown()
    }

    // MARK: - execute(localIdentifier:)

    func testExecute_callsFetchImageDataOnce() async throws {
        _ = try await sut.execute(localIdentifier: "some-id")
        XCTAssertEqual(mockImageRepository.fetchImageDataCallCount, 1)
    }

    func testExecute_forwardsLocalIdentifierToRepository() async throws {
        _ = try await sut.execute(localIdentifier: "photo-99")
        XCTAssertEqual(mockImageRepository.fetchedLocalIdentifier, "photo-99")
    }

    func testExecute_returnsDataFromRepository() async throws {
        let expected = Data([0x01, 0x02, 0x03])
        mockImageRepository.fetchImageDataResult = expected
        let result = try await sut.execute(localIdentifier: "any-id")
        XCTAssertEqual(result, expected)
    }

    func testExecute_whenRepositoryThrows_propagatesError() async {
        mockImageRepository.throwOnFetchImageData = true
        do {
            _ = try await sut.execute(localIdentifier: "any-id")
            XCTFail("Expected execute(localIdentifier:) to throw")
        } catch {
            XCTAssertEqual(error as? LoadSlideImageUseCaseTestError, .intentional)
        }
    }
}
