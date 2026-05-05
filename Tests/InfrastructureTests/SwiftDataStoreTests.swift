import XCTest
import SwiftData
@testable import TenSlide

final class SwiftDataStoreTests: XCTestCase {
    private var sut: SwiftDataStore!
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        sut = SwiftDataStore(modelContainer: container)
    }

    override func tearDown() async throws {
        sut = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - fetch

    func testFetch_onFreshContainer_returnsEmptyArray() async throws {
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.name }
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - write -> fetch

    func testWriteThenFetch_returnsNonEmptyArray() async throws {
        try await sut.write { context in
            let model = SlideshowModel(name: "Test Show")
            context.insert(model)
            try context.save()
        }
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.name }
        XCTAssertEqual(results.count, 1)
    }

    func testWriteThenFetch_returnsSavedName() async throws {
        try await sut.write { context in
            let model = SlideshowModel(name: "My Slideshow")
            context.insert(model)
            try context.save()
        }
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.name }
        XCTAssertEqual(results[0], "My Slideshow")
    }

    func testWriteThenFetch_returnsSavedID() async throws {
        let id = UUID()
        try await sut.write { context in
            let model = SlideshowModel(id: id, name: "ID Test")
            context.insert(model)
            try context.save()
        }
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.id }
        XCTAssertEqual(results[0], id)
    }

    func testWriteThenFetch_returnsSavedDurationRawValue() async throws {
        try await sut.write { context in
            let model = SlideshowModel(name: "X", durationRawValue: "30")
            context.insert(model)
            try context.save()
        }
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.durationRawValue }
        XCTAssertEqual(results[0], "30")
    }

    func testWriteThenFetch_returnsSavedTransitionRawValue() async throws {
        try await sut.write { context in
            let model = SlideshowModel(name: "X", transitionRawValue: "dissolve")
            context.insert(model)
            try context.save()
        }
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.transitionRawValue }
        XCTAssertEqual(results[0], "dissolve")
    }

    func testWriteThenFetch_returnsSavedLoop() async throws {
        try await sut.write { context in
            let model = SlideshowModel(name: "X", loop: false)
            context.insert(model)
            try context.save()
        }
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.loop }
        XCTAssertEqual(results[0], false)
    }

    // MARK: - fetch with predicate

    func testFetch_withPredicate_returnsMatchingModel() async throws {
        let id = UUID()
        try await sut.write { context in
            context.insert(SlideshowModel(id: id, name: "Target"))
            context.insert(SlideshowModel(name: "Other"))
            try context.save()
        }
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        let results = try await sut.fetch(descriptor) { $0.name }
        XCTAssertEqual(results, ["Target"])
    }

    // MARK: - delete

    func testDelete_removesMatchingModel() async throws {
        let id = UUID()
        try await sut.write { context in
            context.insert(SlideshowModel(id: id, name: "To Delete"))
            try context.save()
        }
        try await sut.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.name }
        XCTAssertTrue(results.isEmpty)
    }

    func testDelete_doesNotRemoveOtherModels() async throws {
        let keepID = UUID()
        let removeID = UUID()
        try await sut.write { context in
            context.insert(SlideshowModel(id: keepID, name: "Keep"))
            context.insert(SlideshowModel(id: removeID, name: "Remove"))
            try context.save()
        }
        try await sut.delete(SlideshowModel.self, where: #Predicate { $0.id == removeID })
        let results = try await sut.fetch(FetchDescriptor<SlideshowModel>()) { $0.id }
        XCTAssertEqual(results, [keepID])
    }
}
