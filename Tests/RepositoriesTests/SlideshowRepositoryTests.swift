import XCTest
@testable import TenSlide

// MARK: - Mocks

final class MockSlideshowDataSource: SlideshowDataSourceProtocol, @unchecked Sendable {
    var fetchAllResult: [SlideshowDTO] = []
    var fetchAllCallCount = 0

    var fetchResult: SlideshowDTO?
    var fetchCallCount = 0
    var fetchedID: UUID?

    var saveCallCount = 0
    var savedModel: SlideshowDTO?

    var deleteCallCount = 0
    var deletedID: UUID?

    var throwOnFetchAll = false
    var throwOnFetch = false
    var throwOnSave = false
    var throwOnDelete = false

    func fetchAll() async throws -> [SlideshowDTO] {
        fetchAllCallCount += 1
        if throwOnFetchAll { throw SlideshowRepoTestError.intentional }
        return fetchAllResult
    }

    func fetch(id: UUID) async throws -> SlideshowDTO? {
        fetchCallCount += 1
        fetchedID = id
        if throwOnFetch { throw SlideshowRepoTestError.intentional }
        return fetchResult
    }

    func save(_ dto: SlideshowDTO) async throws {
        saveCallCount += 1
        savedModel = dto
        if throwOnSave { throw SlideshowRepoTestError.intentional }
    }

    func delete(id: UUID) async throws {
        deleteCallCount += 1
        deletedID = id
        if throwOnDelete { throw SlideshowRepoTestError.intentional }
    }
}

private enum SlideshowRepoTestError: Error {
    case intentional
}

// MARK: - SlideshowRepositoryTests

final class SlideshowRepositoryTests: XCTestCase {
    private var sut: SlideshowRepository!
    private var mockSlideshowDataSource: MockSlideshowDataSource!

    override func setUp() {
        super.setUp()
        mockSlideshowDataSource = MockSlideshowDataSource()
        sut = SlideshowRepository(slideshowDataSource: mockSlideshowDataSource)
    }

    override func tearDown() {
        sut = nil
        mockSlideshowDataSource = nil
        super.tearDown()
    }

    // MARK: - fetchAll()

    func testFetchAll_callsDataSourceOnce() async throws {
        _ = try await sut.fetchAll()
        XCTAssertEqual(mockSlideshowDataSource.fetchAllCallCount, 1)
    }

    func testFetchAll_onEmptyDataSource_returnsEmptyArray() async throws {
        mockSlideshowDataSource.fetchAllResult = []
        let result = try await sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }

    func testFetchAll_returnsCorrectCount() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "A"),
            SlideshowDTO(id: UUID(), name: "B")
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result.count, 2)
    }

    func testFetchAll_mapsID() async throws {
        let id = UUID()
        mockSlideshowDataSource.fetchAllResult = [SlideshowDTO(id: id, name: "X")]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].id, id)
    }

    func testFetchAll_mapsName() async throws {
        mockSlideshowDataSource.fetchAllResult = [SlideshowDTO(id: UUID(), name: "My Show")]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].name, "My Show")
    }

    func testFetchAll_mapsDurationRawValue() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", durationRawValue: "30")
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].config.duration, .thirty)
    }

    func testFetchAll_mapsTransitionRawValueToEnum() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", transitionRawValue: "dissolve")
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].config.transition, .dissolve)
    }

    func testFetchAll_mapsLoopFalse() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", loop: false)
        ]
        let result = try await sut.fetchAll()
        XCTAssertFalse(result[0].config.loop)
    }

    func testFetchAll_mapsLoopTrue() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", loop: true)
        ]
        let result = try await sut.fetchAll()
        XCTAssertTrue(result[0].config.loop)
    }

    func testFetchAll_unknownTransitionRawValue_fallsBackToFade() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", transitionRawValue: "zoom")
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].config.transition, .fade)
    }

    func testFetchAll_whenDataSourceThrows_propagatesError() async {
        mockSlideshowDataSource.throwOnFetchAll = true
        do {
            _ = try await sut.fetchAll()
            XCTFail("Expected fetchAll() to throw")
        } catch {
            // error was propagated correctly
        }
    }

    // MARK: - fetch(id:)

    func testFetch_callsDataSourceOnce() async throws {
        _ = try await sut.fetch(id: UUID())
        XCTAssertEqual(mockSlideshowDataSource.fetchCallCount, 1)
    }

    func testFetch_forwardsIDToDataSource() async throws {
        let id = UUID()
        _ = try await sut.fetch(id: id)
        XCTAssertEqual(mockSlideshowDataSource.fetchedID, id)
    }

    func testFetch_whenModelNotFound_returnsNil() async throws {
        mockSlideshowDataSource.fetchResult = nil
        let result = try await sut.fetch(id: UUID())
        XCTAssertNil(result)
    }

    func testFetch_whenModelFound_returnsNonNil() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "Found")
        let result = try await sut.fetch(id: UUID())
        XCTAssertNotNil(result)
    }

    func testFetch_mapsID() async throws {
        let id = UUID()
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: id, name: "X")
        let result = try await sut.fetch(id: id)
        XCTAssertEqual(result?.id, id)
    }

    func testFetch_mapsDurationRawValue() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", durationRawValue: "60")
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.config.duration, .sixty)
    }

    func testFetch_mapsTransitionRawValue() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", transitionRawValue: "slide")
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.config.transition, .slide)
    }

    func testFetch_mapsLoop() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", loop: false)
        let result = try await sut.fetch(id: UUID())
        XCTAssertFalse(result?.config.loop ?? true)
    }

    func testFetch_unknownTransitionRawValue_fallsBackToFade() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", transitionRawValue: "wipe")
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.config.transition, .fade)
    }

    func testFetch_whenDataSourceThrows_propagatesError() async {
        mockSlideshowDataSource.throwOnFetch = true
        do {
            _ = try await sut.fetch(id: UUID())
            XCTFail("Expected fetch(id:) to throw")
        } catch {
            // error was propagated correctly
        }
    }

    // MARK: - save()

    func testSave_callsDataSourceOnce() async throws {
        try await sut.save(makeSlideshow())
        XCTAssertEqual(mockSlideshowDataSource.saveCallCount, 1)
    }

    func testSave_encodesID() async throws {
        let slideshow = makeSlideshow()
        try await sut.save(slideshow)
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.id, slideshow.id)
    }

    func testSave_encodesName() async throws {
        let slideshow = makeSlideshow(name: "Encoded Show")
        try await sut.save(slideshow)
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.name, "Encoded Show")
    }

    func testSave_encodesDurationAsRawValue() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .fifteen, transition: .fade, loop: true)
        )
        try await sut.save(slideshow)
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.durationRawValue, "15")
    }

    func testSave_encodesTransitionAsRawValue() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .five, transition: .dissolve, loop: true)
        )
        try await sut.save(slideshow)
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.transitionRawValue, "dissolve")
    }

    func testSave_encodesLoopFalse() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .five, transition: .fade, loop: false)
        )
        try await sut.save(slideshow)
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.loop, false)
    }

    func testSave_encodesLoopTrue() async throws {
        let slideshow = makeSlideshow(
            config: SlideshowConfig(duration: .five, transition: .fade, loop: true)
        )
        try await sut.save(slideshow)
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.loop, true)
    }

    func testSave_whenDataSourceThrows_propagatesError() async {
        mockSlideshowDataSource.throwOnSave = true
        do {
            try await sut.save(makeSlideshow())
            XCTFail("Expected save() to throw")
        } catch {
            // error was propagated correctly
        }
    }

    // MARK: - delete()

    func testDelete_callsDataSourceOnce() async throws {
        try await sut.delete(id: UUID())
        XCTAssertEqual(mockSlideshowDataSource.deleteCallCount, 1)
    }

    func testDelete_forwardsIDToDataSource() async throws {
        let id = UUID()
        try await sut.delete(id: id)
        XCTAssertEqual(mockSlideshowDataSource.deletedID, id)
    }

    func testDelete_whenDataSourceThrows_propagatesError() async {
        mockSlideshowDataSource.throwOnDelete = true
        do {
            try await sut.delete(id: UUID())
            XCTFail("Expected delete(id:) to throw")
        } catch {
            // error was propagated correctly
        }
    }

    // MARK: - fetchAll() slides mapping

    func testFetchAll_mapsSlideCount() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "a", order: 0),
                SlideDTO(localIdentifier: "b", order: 1)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides.count, 2)
    }

    func testFetchAll_mapsSlideLocalIdentifier() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "slide-id", order: 0, duration: 4.0)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].localIdentifier, "slide-id")
    }

    func testFetchAll_mapsSlideOrder() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "x", order: 7)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].order, 7)
    }

    func testFetchAll_mapsSlideID() async throws {
        let slideID = UUID()
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(id: slideID, localIdentifier: "x", order: 0)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].id, slideID)
    }

    func testFetchAll_mapsSlideTitle() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "x", order: 0, title: "My Title")
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].title, "My Title")
    }

    func testFetchAll_mapsSlideNilTitle() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "x", order: 0, title: nil)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertNil(result[0].slides[0].title)
    }

    func testFetchAll_sortsSlidesByOrder_firstSlideIsFirst() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "second", order: 1),
                SlideDTO(localIdentifier: "first", order: 0)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[0].localIdentifier, "first")
    }

    func testFetchAll_sortsSlidesByOrder_secondSlideIsSecond() async throws {
        mockSlideshowDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "X", slides: [
                SlideDTO(localIdentifier: "second", order: 1),
                SlideDTO(localIdentifier: "first", order: 0)
            ])
        ]
        let result = try await sut.fetchAll()
        XCTAssertEqual(result[0].slides[1].localIdentifier, "second")
    }

    // MARK: - fetch(id:) slides mapping

    func testFetch_mapsSlideCount() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", slides: [
            SlideDTO(localIdentifier: "a", order: 0),
            SlideDTO(localIdentifier: "b", order: 1)
        ])
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.slides.count, 2)
    }

    func testFetch_mapsSlideLocalIdentifier() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", slides: [
            SlideDTO(localIdentifier: "slide-id", order: 0, duration: 4.0)
        ])
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.slides[0].localIdentifier, "slide-id")
    }

    func testFetch_sortsSlidesByOrder_firstSlideIsFirst() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", slides: [
            SlideDTO(localIdentifier: "second", order: 1),
            SlideDTO(localIdentifier: "first", order: 0)
        ])
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.slides[0].localIdentifier, "first")
    }

    func testFetch_sortsSlidesByOrder_secondSlideIsSecond() async throws {
        mockSlideshowDataSource.fetchResult = SlideshowDTO(id: UUID(), name: "X", slides: [
            SlideDTO(localIdentifier: "second", order: 1),
            SlideDTO(localIdentifier: "first", order: 0)
        ])
        let result = try await sut.fetch(id: UUID())
        XCTAssertEqual(result?.slides[1].localIdentifier, "second")
    }

    // MARK: - save() slide mapping

    func testSave_encodesSlideCount() async throws {
        let slides = [
            Slide(id: UUID(), localIdentifier: "a", order: 0, duration: 3.0, title: nil),
            Slide(id: UUID(), localIdentifier: "b", order: 1, duration: 3.0, title: nil)
        ]
        try await sut.save(makeSlideshow(slides: slides))
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.slides.count, 2)
    }

    func testSave_encodesSlideLocalIdentifier() async throws {
        let slide = Slide(id: UUID(), localIdentifier: "abc", order: 0, duration: 3.0, title: nil)
        try await sut.save(makeSlideshow(slides: [slide]))
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.slides.first?.localIdentifier, "abc")
    }

    func testSave_encodesSlideOrder() async throws {
        let slide = Slide(id: UUID(), localIdentifier: "x", order: 2, duration: 3.0, title: nil)
        try await sut.save(makeSlideshow(slides: [slide]))
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.slides.first?.order, 2)
    }

    func testSave_encodesSlideID() async throws {
        let slideID = UUID()
        let slide = Slide(id: slideID, localIdentifier: "x", order: 0, duration: 3.0, title: nil)
        try await sut.save(makeSlideshow(slides: [slide]))
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.slides.first?.id, slideID)
    }

    func testSave_encodesSlideTitle() async throws {
        let slide = Slide(id: UUID(), localIdentifier: "x", order: 0, duration: 3.0, title: "Caption")
        try await sut.save(makeSlideshow(slides: [slide]))
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.slides.first?.title, "Caption")
    }

    func testSave_encodesSlideNilTitle() async throws {
        let slide = Slide(id: UUID(), localIdentifier: "x", order: 0, duration: 3.0, title: nil)
        try await sut.save(makeSlideshow(slides: [slide]))
        XCTAssertNil(mockSlideshowDataSource.savedModel?.slides.first?.title)
    }

    func testSave_encodesSlideCount_multipleSlides() async throws {
        let slides = [
            Slide(id: UUID(), localIdentifier: "a", order: 0, duration: 3.0, title: nil),
            Slide(id: UUID(), localIdentifier: "b", order: 1, duration: 3.0, title: nil),
            Slide(id: UUID(), localIdentifier: "c", order: 2, duration: 3.0, title: nil)
        ]
        try await sut.save(makeSlideshow(slides: slides))
        XCTAssertEqual(mockSlideshowDataSource.savedModel?.slides.count, 3)
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
