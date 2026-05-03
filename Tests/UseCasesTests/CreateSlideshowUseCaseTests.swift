import XCTest
@testable import TenSlide

// MARK: - Mocks

final class MockSlideshowRepositoryForCreate: SlideshowRepositoryProtocol, @unchecked Sendable {
    var fetchAllResult: [Slideshow] = []
    var fetchResult: Slideshow?
    var saveCallCount = 0
    var savedSlideshow: Slideshow?
    var throwOnSave = false

    func fetchAll() async throws -> [Slideshow] { fetchAllResult }

    func fetch(id: UUID) async throws -> Slideshow? { fetchResult }

    func save(_ slideshow: Slideshow) async throws {
        saveCallCount += 1
        savedSlideshow = slideshow
        if throwOnSave { throw CreateSlideshowUseCaseTestError.intentional }
    }

    func delete(id: UUID) async throws {}
}

final class MockConfigRepositoryForCreate: ConfigRepositoryProtocol, @unchecked Sendable {
    var loadResult: SlideshowConfig = .default
    var loadCallCount = 0
    var throwOnLoad = false

    func load() async throws -> SlideshowConfig {
        loadCallCount += 1
        if throwOnLoad { throw CreateSlideshowUseCaseTestError.intentional }
        return loadResult
    }

    func save(_ config: SlideshowConfig) async throws {}
}

private enum CreateSlideshowUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - CreateSlideshowUseCaseTests

final class CreateSlideshowUseCaseTests: XCTestCase {
    private var sut: CreateSlideshowUseCase!
    private var mockSlideshowRepository: MockSlideshowRepositoryForCreate!
    private var mockConfigRepository: MockConfigRepositoryForCreate!

    override func setUp() {
        super.setUp()
        mockSlideshowRepository = MockSlideshowRepositoryForCreate()
        mockConfigRepository = MockConfigRepositoryForCreate()
        sut = CreateSlideshowUseCase(
            slideshowRepository: mockSlideshowRepository,
            configRepository: mockConfigRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockSlideshowRepository = nil
        mockConfigRepository = nil
        super.tearDown()
    }

    // MARK: - execute(name:localIdentifiers:)

    func testExecute_callsConfigRepositoryLoadOnce() async throws {
        _ = try await sut.execute(name: "Show", localIdentifiers: ["a"])
        XCTAssertEqual(mockConfigRepository.loadCallCount, 1)
    }

    func testExecute_callsSlideshowRepositorySaveOnce() async throws {
        _ = try await sut.execute(name: "Show", localIdentifiers: ["a"])
        XCTAssertEqual(mockSlideshowRepository.saveCallCount, 1)
    }

    func testExecute_buildsSlide_withConfigDefaultDuration() async throws {
        mockConfigRepository.loadResult = SlideshowConfig(defaultDuration: 8.0, transition: .fade, loop: true)
        let result = try await sut.execute(name: "Show", localIdentifiers: ["id1"])
        XCTAssertEqual(result.slides[0].duration, 8.0)
    }

    func testExecute_buildsCorrectSlideCount() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a", "b", "c"])
        XCTAssertEqual(result.slides.count, 3)
    }

    func testExecute_buildsSlide_withCorrectLocalIdentifier() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["photo-42"])
        XCTAssertEqual(result.slides[0].localIdentifier, "photo-42")
    }

    func testExecute_buildsSlide_firstIndexIsOrderZero() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a", "b"])
        XCTAssertEqual(result.slides[0].order, 0)
    }

    func testExecute_buildsSlide_secondIndexIsOrderOne() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a", "b"])
        XCTAssertEqual(result.slides[1].order, 1)
    }

    func testExecute_buildsSlide_withNilTitle() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a"])
        XCTAssertNil(result.slides[0].title)
    }

    func testExecute_returnsSlideshowWithMatchingName() async throws {
        let result = try await sut.execute(name: "My Vacation", localIdentifiers: ["a"])
        XCTAssertEqual(result.name, "My Vacation")
    }

    func testExecute_returnsSlideshowWithMatchingConfig() async throws {
        let config = SlideshowConfig(defaultDuration: 3.0, transition: .dissolve, loop: false)
        mockConfigRepository.loadResult = config
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a"])
        XCTAssertEqual(result.config, config)
    }

    func testExecute_whenIdentifiersEmpty_returnsEmptySlides() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: [])
        XCTAssertTrue(result.slides.isEmpty)
    }

    func testExecute_saveCalledWithMatchingName() async throws {
        _ = try await sut.execute(name: "Saved Show", localIdentifiers: ["a"])
        XCTAssertEqual(mockSlideshowRepository.savedSlideshow?.name, "Saved Show")
    }

    func testExecute_saveCalledWithCorrectSlideCount() async throws {
        _ = try await sut.execute(name: "Show", localIdentifiers: ["x", "y"])
        XCTAssertEqual(mockSlideshowRepository.savedSlideshow?.slides.count, 2)
    }

    func testExecute_saveCalledWithMatchingSlideDuration() async throws {
        mockConfigRepository.loadResult = SlideshowConfig(defaultDuration: 12.0, transition: .fade, loop: true)
        _ = try await sut.execute(name: "Show", localIdentifiers: ["z"])
        XCTAssertEqual(mockSlideshowRepository.savedSlideshow?.slides[0].duration, 12.0)
    }

    func testExecute_whenConfigRepositoryThrows_propagatesError() async {
        mockConfigRepository.throwOnLoad = true
        do {
            _ = try await sut.execute(name: "Show", localIdentifiers: ["a"])
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? CreateSlideshowUseCaseTestError, .intentional)
        }
    }

    func testExecute_whenSlideshowRepositoryThrows_propagatesError() async {
        mockSlideshowRepository.throwOnSave = true
        do {
            _ = try await sut.execute(name: "Show", localIdentifiers: ["a"])
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? CreateSlideshowUseCaseTestError, .intentional)
        }
    }
}
