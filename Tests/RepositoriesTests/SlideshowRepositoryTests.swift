import XCTest
import SwiftData
@testable import TenSlide

// MARK: - SlideshowRepositoryTests

final class SlideshowRepositoryTests: XCTestCase {
    private var sut: SlideshowRepository!
    private var store: SwiftDataStore!
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        store = SwiftDataStore(modelContainer: container)
        sut = SlideshowRepository(store: store)
    }

    override func tearDown() async throws {
        sut = nil
        store = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - fetchAll()

    func testFetchAll_onEmpty_returnsEmptyArray() async throws {
        let result = try await sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }

    func testFetchAll_returnsCorrectCount() async throws {
        try await sut.save(makeSlideshow(name: "A"))
        try await sut.save(makeSlideshow(name: "B"))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result.count, 2)
    }

    func testFetchAll_mapsID() async throws {
        let slideshow = makeSlideshow()
        try await sut.save(slideshow)
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].id, slideshow.id)
    }

    func testFetchAll_mapsName() async throws {
        try await sut.save(makeSlideshow(name: "My Show"))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].name, "My Show")
    }

    func testFetchAll_mapsDuration() async throws {
        try await sut.save(makeSlideshow(config: SlideshowConfig(duration: .thirty, transition: .fade, loop: true)))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].config.duration, .thirty)
    }

    func testFetchAll_mapsTransition() async throws {
        try await sut.save(makeSlideshow(config: SlideshowConfig(duration: .five, transition: .dissolve, loop: true)))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].config.transition, .dissolve)
    }

    func testFetchAll_mapsLoopFalse() async throws {
        try await sut.save(makeSlideshow(config: SlideshowConfig(duration: .five, transition: .fade, loop: false)))
        let result = try await sut.fetchAll()
        XCTAssertFalse(result[0].config.loop)
    }

    func testFetchAll_mapsLoopTrue() async throws {
        try await sut.save(makeSlideshow(config: SlideshowConfig(duration: .five, transition: .fade, loop: true)))
        let result = try await sut.fetchAll()
        XCTAssertTrue(result[0].config.loop)
    }

    // MARK: - fetch(id:)

    func testFetch_whenIDNotFound_returnsNil() async throws {
        let result = try await sut.fetch(id: UUID())
        XCTAssertNil(result)
    }

    func testFetch_whenModelFound_returnsNonNil() async throws {
        let slideshow = makeSlideshow()
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertNotNil(result)
    }

    func testFetch_mapsID() async throws {
        let slideshow = makeSlideshow()
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertEqual(result?.id, slideshow.id)
    }

    func testFetch_mapsName() async throws {
        let slideshow = makeSlideshow(name: "Found Show")
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertEqual(result?.name, "Found Show")
    }

    func testFetch_mapsDuration() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .sixty, transition: .fade, loop: true)
        )
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertEqual(result?.config.duration, .sixty)
    }

    func testFetch_mapsTransition() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .five, transition: .slide, loop: true)
        )
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertEqual(result?.config.transition, .slide)
    }

    func testFetch_mapsLoop() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .five, transition: .fade, loop: false)
        )
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertFalse(result?.config.loop ?? true)
    }

    // MARK: - save()

    func testSave_encodesID() async throws {
        let slideshow = makeSlideshow()
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertEqual(result?.id, slideshow.id)
    }

    func testSave_encodesName() async throws {
        let slideshow = makeSlideshow(name: "Encoded Show")
        try await sut.save(slideshow)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertEqual(result?.name, "Encoded Show")
    }

    // MARK: - delete()

    func testDelete_makesModelUnfetchableByID() async throws {
        let slideshow = makeSlideshow()
        try await sut.save(slideshow)
        try await sut.delete(id: slideshow.id)
        let result = try await sut.fetch(id: slideshow.id)
        XCTAssertNil(result)
    }

    func testDelete_reducesCountByOne() async throws {
        let first = makeSlideshow(name: "First")
        let second = makeSlideshow(name: "Second")
        try await sut.save(first)
        try await sut.save(second)
        try await sut.delete(id: first.id)
        let all = try await sut.fetchAll()
        XCTAssertEqual(all.count, 1)
    }

    func testDelete_doesNotRemoveOtherModels() async throws {
        let keep = makeSlideshow(name: "Keep")
        let remove = makeSlideshow(name: "Remove")
        try await sut.save(keep)
        try await sut.save(remove)
        try await sut.delete(id: remove.id)
        let result = try await sut.fetch(id: keep.id)
        XCTAssertEqual(result?.id, keep.id)
    }

    // MARK: - Slide mapping

    func testFetchAll_mapsSlideCount() async throws {
        let slides = [
            Slide(id: UUID(), localIdentifier: "a", order: 0, duration: 5.0, title: nil),
            Slide(id: UUID(), localIdentifier: "b", order: 1, duration: 5.0, title: nil)
        ]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides.count, 2)
    }

    func testFetchAll_mapsSlideLocalIdentifier() async throws {
        let slides = [Slide(id: UUID(), localIdentifier: "slide-id", order: 0, duration: 4.0, title: nil)]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].localIdentifier, "slide-id")
    }

    func testFetchAll_mapsSlideOrder() async throws {
        let slides = [Slide(id: UUID(), localIdentifier: "x", order: 7, duration: 5.0, title: nil)]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].order, 7)
    }

    func testFetchAll_mapsSlideID() async throws {
        let slideID = UUID()
        let slides = [Slide(id: slideID, localIdentifier: "x", order: 0, duration: 5.0, title: nil)]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].id, slideID)
    }

    func testFetchAll_mapsSlideTitle() async throws {
        let slides = [Slide(id: UUID(), localIdentifier: "x", order: 0, duration: 5.0, title: "My Title")]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].title, "My Title")
    }

    func testFetchAll_mapsSlideNilTitle() async throws {
        let slides = [Slide(id: UUID(), localIdentifier: "x", order: 0, duration: 5.0, title: nil)]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertNil(result[0].slides[0].title)
    }

    func testFetchAll_sortsSlidesByOrder() async throws {
        let slides = [
            Slide(id: UUID(), localIdentifier: "second", order: 1, duration: 5.0, title: nil),
            Slide(id: UUID(), localIdentifier: "first", order: 0, duration: 5.0, title: nil)
        ]
        try await sut.save(makeSlideshow(slides: slides))
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].localIdentifier, "first")
    }

    // MARK: - Helpers

    private func makeSlideshow(
        id: UUID = UUID(),
        name: String = "Test Slideshow",
        slides: [Slide] = [],
        config: SlideshowConfig = SlideshowConfig(duration: .five, transition: .fade, loop: true)
    ) -> Slideshow {
        Slideshow(id: id, name: name, slides: slides, config: config, createdAt: Date())
    }
}
