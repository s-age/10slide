import XCTest
@testable import TenSlide

// MARK: - Mock

final class MockSlideshowDomainServiceForCreate: SlideshowDomainServiceProtocol, @unchecked Sendable {
    var createResult: Slideshow = Slideshow(
        id: UUID(), name: "Mock", slides: [], config: .default, createdAt: Date()
    )
    var createCallCount = 0
    var createdName: String?
    var createdIdentifiers: [String]?
    var createdConfig: SlideshowConfig?
    var throwOnCreate = false

    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        createCallCount += 1
        createdName = name
        createdIdentifiers = localIdentifiers
        createdConfig = config
        if throwOnCreate { throw CreateSlideshowUseCaseTestError.intentional }
        return createResult
    }

    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        Slideshow(id: id, name: name, slides: [], config: .default, createdAt: Date())
    }

    func delete(id: UUID) async throws {}
    func fetch(id: UUID) async throws -> Slideshow? { nil }
    func fetchAll() async throws -> [Slideshow] { [] }
}

private enum CreateSlideshowUseCaseTestError: Error, Equatable {
    case intentional
}

// MARK: - CreateSlideshowUseCaseTests

final class CreateSlideshowUseCaseTests: XCTestCase {
    private var sut: CreateSlideshowUseCase!
    private var mockDomainService: MockSlideshowDomainServiceForCreate!

    override func setUp() {
        super.setUp()
        mockDomainService = MockSlideshowDomainServiceForCreate()
        sut = CreateSlideshowUseCase(domainService: mockDomainService)
    }

    override func tearDown() {
        sut = nil
        mockDomainService = nil
        super.tearDown()
    }

    // MARK: - execute(_:)

    func testExecute_callsDomainServiceCreateOnce() async throws {
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.createCallCount, 1)
    }

    func testExecute_forwardsNameToDomainService() async throws {
        let request = CreateSlideshowRequest(
            name: "My Vacation", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.createdName, "My Vacation")
    }

    func testExecute_forwardsIdentifiersToDomainService() async throws {
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["x", "y", "z"], duration: .five, transition: .fade, loop: true
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.createdIdentifiers, ["x", "y", "z"])
    }

    func testExecute_forwardsDurationToDomainService() async throws {
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .thirty, transition: .fade, loop: true
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.createdConfig?.duration, .thirty)
    }

    func testExecute_forwardsTransitionToDomainService() async throws {
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .five, transition: .dissolve, loop: true
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.createdConfig?.transition, .dissolve)
    }

    func testExecute_forwardsLoopToDomainService() async throws {
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: false
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(mockDomainService.createdConfig?.loop, false)
    }

    func testExecute_returnsSlideshowResponseWithMatchingID() async throws {
        let expectedID = UUID()
        mockDomainService.createResult = Slideshow(
            id: expectedID, name: "Show", slides: [], config: .default, createdAt: Date()
        )
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        let result = try await sut.execute(request)
        XCTAssertEqual(result.id, expectedID)
    }

    func testExecute_returnsSlideshowResponseWithMatchingName() async throws {
        mockDomainService.createResult = Slideshow(
            id: UUID(), name: "Vacation", slides: [], config: .default, createdAt: Date()
        )
        let request = CreateSlideshowRequest(
            name: "Vacation", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        let result = try await sut.execute(request)
        XCTAssertEqual(result.name, "Vacation")
    }

    func testExecute_whenDomainServiceThrows_propagatesError() async {
        mockDomainService.throwOnCreate = true
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        do {
            _ = try await sut.execute(request)
            XCTFail("Expected execute() to throw")
        } catch {
            XCTAssertEqual(error as? CreateSlideshowUseCaseTestError, .intentional)
        }
    }

    // MARK: - Validation

    func testExecute_withEmptyName_throwsValidationError() async {
        let request = CreateSlideshowRequest(
            name: "", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        do {
            _ = try await sut.execute(request)
            XCTFail("Expected execute() to throw validation error")
        } catch {
            XCTAssertEqual(error as? ValidationError, .emptyName)
        }
    }

    func testExecute_withEmptyIdentifiers_throwsValidationError() async {
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: [], duration: .five, transition: .fade, loop: true
        )
        do {
            _ = try await sut.execute(request)
            XCTFail("Expected execute() to throw validation error")
        } catch {
            XCTAssertEqual(error as? ValidationError, .noIdentifiers)
        }
    }

    func testExecute_withEmptyName_doesNotCallDomainService() async {
        let request = CreateSlideshowRequest(
            name: "", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        _ = try? await sut.execute(request)
        XCTAssertEqual(mockDomainService.createCallCount, 0)
    }
}
