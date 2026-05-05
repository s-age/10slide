import XCTest
@testable import TenSlide

// MARK: - Stub: Async UseCase

private final class StubAsyncUseCase: AsyncUseCase, @unchecked Sendable {
    var executeCallCount = 0

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        executeCallCount += 1
        return SlideshowResponse(
            id: UUID(), name: request.name, slides: [], config: .default, createdAt: Date()
        )
    }
}

// MARK: - Stub: Sync UseCase

private final class StubSyncUseCase: SyncUseCase, @unchecked Sendable {
    var executeCallCount = 0

    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        executeCallCount += 1
        return request.currentIndex + 1
    }
}

// MARK: - ValidationUseCaseDecoratorTests

final class ValidationUseCaseDecoratorTests: XCTestCase {

    // MARK: - Async Decorator

    func testAsyncDecorator_withValidRequest_delegatesToDecoratee() async throws {
        let stub = StubAsyncUseCase()
        let sut = ValidationAsyncUseCaseDecorator(decoratee: stub)
        let request = CreateSlideshowRequest(
            name: "Show", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        _ = try await sut.execute(request)
        XCTAssertEqual(stub.executeCallCount, 1)
    }

    func testAsyncDecorator_withInvalidRequest_throwsValidationError() async {
        let stub = StubAsyncUseCase()
        let sut = ValidationAsyncUseCaseDecorator(decoratee: stub)
        let request = CreateSlideshowRequest(
            name: "", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        do {
            _ = try await sut.execute(request)
            XCTFail("Expected validation error")
        } catch {
            XCTAssertEqual(error as? ValidationError, .emptyName)
        }
    }

    func testAsyncDecorator_withInvalidRequest_doesNotCallDecoratee() async {
        let stub = StubAsyncUseCase()
        let sut = ValidationAsyncUseCaseDecorator(decoratee: stub)
        let request = CreateSlideshowRequest(
            name: "", localIdentifiers: ["a"], duration: .five, transition: .fade, loop: true
        )
        _ = try? await sut.execute(request)
        XCTAssertEqual(stub.executeCallCount, 0)
    }

    // MARK: - Sync Decorator

    func testSyncDecorator_withValidRequest_delegatesToDecoratee() throws {
        let stub = StubSyncUseCase()
        let sut = ValidationSyncUseCaseDecorator(decoratee: stub)
        let request = AdvanceSlideRequest(totalSlides: 3, currentIndex: 0, loop: false)
        _ = try sut.execute(request)
        XCTAssertEqual(stub.executeCallCount, 1)
    }

    func testSyncDecorator_withInvalidRequest_throwsValidationError() {
        let stub = StubSyncUseCase()
        let sut = ValidationSyncUseCaseDecorator(decoratee: stub)
        let request = AdvanceSlideRequest(totalSlides: 0, currentIndex: 0, loop: false)
        do {
            _ = try sut.execute(request)
            XCTFail("Expected validation error")
        } catch {
            XCTAssertEqual(error as? ValidationError, .noSlides)
        }
    }

    func testSyncDecorator_withInvalidRequest_doesNotCallDecoratee() {
        let stub = StubSyncUseCase()
        let sut = ValidationSyncUseCaseDecorator(decoratee: stub)
        let request = AdvanceSlideRequest(totalSlides: 0, currentIndex: 0, loop: false)
        _ = try? sut.execute(request)
        XCTAssertEqual(stub.executeCallCount, 0)
    }
}
