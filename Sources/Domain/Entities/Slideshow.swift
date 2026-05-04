import Foundation

struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig
    var createdAt: Date

    func nextSlideIndex(from currentIndex: Int) -> Int? {
        guard !slides.isEmpty else { return nil }
        if currentIndex < slides.count - 1 { return currentIndex + 1 }
        return config.loop ? 0 : nil
    }

    func previousSlideIndex(from currentIndex: Int) -> Int? {
        guard !slides.isEmpty else { return nil }
        if currentIndex > 0 { return currentIndex - 1 }
        return config.loop ? slides.count - 1 : nil
    }

    static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
        Slideshow(
            id: UUID(),
            name: name,
            slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
            config: config,
            createdAt: Date()
        )
    }

    func applying(config: SlideshowConfig) -> Slideshow {
        var updated = self
        updated.config = config
        return updated
    }

    func updating(name: String, localIdentifiers: [String]) -> Slideshow {
        var updated = self
        updated.name = name
        updated.slides = Slideshow.makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0)
        return updated
    }

    private static func makeSlides(from localIdentifiers: [String], duration: TimeInterval) -> [Slide] {
        localIdentifiers.enumerated().map { index, id in
            Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
        }
    }
}
