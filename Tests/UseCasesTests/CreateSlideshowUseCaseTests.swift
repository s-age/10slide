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

private enum CreateSlideshowUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - CreateSlideshowUseCaseTests

final class CreateSlideshowUseCaseTests: XCTestCase {
    private var sut: CreateSlideshowUseCase!
    private var mockSlideshowRepository: MockSlideshowRepositoryForCreate!

    override func setUp() {
        super.setUp()
        mockSlideshowRepository = MockSlideshowRepositoryForCreate()
        sut = CreateSlideshowUseCase(slideshowRepository: mockSlideshowRepository)
    }

    override func tearDown() {
        sut = nil
        mockSlideshowRepository = nil
        super.tearDown()
    }

    private let defaultConfig = SlideshowConfig(duration: .five, transition: .fade, loop: true)

    // MARK: - execute(name:localIdentifiers:config:)

    func testExecute_callsSlideshowRepositorySaveOnce() async throws {
        _ = try await sut.execute(name: "Show", localIdentifiers: ["a"], config: defaultConfig)
        XCTAssertEqual(mockSlideshowRepository.saveCallCount, 1)
    }

    func testExecute_buildsSlide_withConfigDurationSeconds() async throws {
        let config = SlideshowConfig(duration: .ten, transition: .fade, loop: true)
        let result = try await sut.execute(name: "Show", localIdentifiers: ["id1"], config: config)
        XCTAssertEqual(result.slides[0].duration, 10.0)
    }

    func testExecute_buildsSlide_manualDurationIsZero() async throws {
        let config = SlideshowConfig(duration: .manual, transition: .fade, loop: true)
        let result = try await sut.execute(name: "Show", localIdentifiers: ["id1"], config: config)
        XCTAssertEqual(result.slides[0].duration, 0.0)
    }

    func testExecute_buildsCorrectSlideCount() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a", "b", "c"], config: defaultConfig)
        XCTAssertEqual(result.slides.count, 3)
    }

    func testExecute_buildsSlide_withCorrectLocalIdentifier() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["photo-42"], config: defaultConfig)
        XCTAssertEqual(result.slides[0].localIdentifier, "photo-42")
    }

    func testExecute_buildsSlide_firstIndexIsOrderZero() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a", "b"], config: defaultConfig)
        XCTAssertEqual(result.slides[0].order, 0)
    }

    func testExecute_buildsSlide_secondIndexIsOrderOne() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a", "b"], config: defaultConfig)
        XCTAssertEqual(result.slides[1].order, 1)
    }

    func testExecute_buildsSlide_withNilTitle() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a"], config: defaultConfig)
        XCTAssertNil(result.slides[0].title)
    }

    func testExecute_returnsSlideshowWithMatchingName() async throws {
        let result = try await sut.execute(name: "My Vacation", localIdentifiers: ["a"], config: defaultConfig)
        XCTAssertEqual(result.name, "My Vacation")
    }

    func testExecute_returnsSlideshowWithMatchingConfig() async throws {
        let config = SlideshowConfig(duration: .thirty, transition: .dissolve, loop: false)
        let result = try await sut.execute(name: "Show", localIdentifiers: ["a"], config: config)
        XCTAssertEqual(result.config, config)
    }

    func testExecute_whenIdentifiersEmpty_returnsEmptySlides() async throws {
        let result = try await sut.execute(name: "Show", localIdentifiers: [], config: defaultConfig)
        XCTAssertTrue(result.slides.isEmpty)
    }

    func testExecute_saveCalledWithMatchingName() async throws {
        _ = try await sut.execute(name: "Saved Show", localIdentifiers: ["a"], config: defaultConfig)
        XCTAssertEqual(mockSlideshowRepository.savedSlideshow?.name, "Saved Show")
    }

    func testExecute_saveCalledWithCorrectSlideCount() async throws {
        _ = try await sut.execute(name: "Show", localIdentifiers: ["x", "y"], config: defaultConfig)
        XCTAssertEqual(mockSlideshowRepository.savedSlideshow?.slides.count, 2)
    }

    func testExecute_saveCalledWithMatchingSlideDuration() async throws {
        let config = SlideshowConfig(duration: .sixty, transition: .fade, loop: true)
        _ = try await sut.execute(name: "Show", localIdentifiers: ["z"], config: config)
        XCTAssertEqual(mockSlideshowRepository.savedSlideshow?.slides[0].duration, 60.0)
    }

    func testExecute_whenSlideshowRepositoryThrows_propagatesError() async {
        mockSlideshowRepository.throwOnSave = true
        do {
            _ = try await sut.execute(name: "Show", localIdentifiers: ["a"], config: defaultConfig)
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? CreateSlideshowUseCaseTestError, .intentional)
        }
    }
}
