import XCTest
import SwiftData
@testable import TenSlide

final class SlideshowDataSourceTests: XCTestCase {
    private var sut: SlideshowDataSource!
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        sut = SlideshowDataSource(container: container)
    }

    override func tearDown() async throws {
        sut = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - fetchAll

    func testFetchAll_onFreshContainer_returnsEmptyArray() async throws {
        let results = try await sut.fetchAll()
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - save → fetch(id:)

    func testSaveThenFetch_returnsNonNilModel() async throws {
        let model = SlideshowModel(id: UUID(), name: "Test Show")
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)
        XCTAssertNotNil(fetched)
    }

    func testSaveThenFetch_returnsSavedID() async throws {
        let id = UUID()
        let model = SlideshowModel(id: id, name: "ID Test")
        try await sut.save(model)
        let fetched = try await sut.fetch(id: id)
        XCTAssertEqual(fetched?.id, id)
    }

    func testSaveThenFetch_returnsSavedName() async throws {
        let model = SlideshowModel(id: UUID(), name: "My Slideshow")
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)
        XCTAssertEqual(fetched?.name, "My Slideshow")
    }

    func testSaveThenFetch_returnsSavedDurationRawValue() async throws {
        let model = SlideshowModel(id: UUID(), name: "X", durationRawValue: "30")
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)
        XCTAssertEqual(fetched?.durationRawValue, "30")
    }

    func testSaveThenFetch_returnsSavedTransitionRawValue() async throws {
        let model = SlideshowModel(id: UUID(), name: "X", transitionRawValue: "crossDissolve")
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)
        XCTAssertEqual(fetched?.transitionRawValue, "crossDissolve")
    }

    func testSaveThenFetch_returnsSavedLoop() async throws {
        let model = SlideshowModel(id: UUID(), name: "X", loop: false)
        try await sut.save(model)
        let fetched = try await sut.fetch(id: model.id)
        XCTAssertEqual(fetched?.loop, false)
    }

    // MARK: - save → fetchAll

    func testSaveThenFetchAll_includesSavedModel() async throws {
        let model = SlideshowModel(id: UUID(), name: "Included")
        try await sut.save(model)
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    // MARK: - fetch(id:) miss

    func testFetch_whenIDNotFound_returnsNil() async throws {
        let fetched = try await sut.fetch(id: UUID())
        XCTAssertNil(fetched)
    }

    // MARK: - delete

    func testDelete_makesModelUnfetchableByID() async throws {
        let model = SlideshowModel(id: UUID(), name: "To Delete")
        try await sut.save(model)
        try await sut.delete(id: model.id)
        let fetched = try await sut.fetch(id: model.id)
        XCTAssertNil(fetched)
    }

    func testDelete_reducesCountByOne() async throws {
        let first = SlideshowModel(id: UUID(), name: "First")
        let second = SlideshowModel(id: UUID(), name: "Second")
        try await sut.save(first)
        try await sut.save(second)
        try await sut.delete(id: first.id)
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func testDelete_doesNotRemoveOtherModels() async throws {
        let keep = SlideshowModel(id: UUID(), name: "Keep")
        let remove = SlideshowModel(id: UUID(), name: "Remove")
        try await sut.save(keep)
        try await sut.save(remove)
        try await sut.delete(id: remove.id)
        let fetched = try await sut.fetch(id: keep.id)
        XCTAssertEqual(fetched?.id, keep.id)
    }
}
