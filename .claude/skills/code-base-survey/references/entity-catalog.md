# Entity Catalog
Updated: 2026-05-03

Layer path: `Sources/Domain/Entities/`

## `Slide.swift`

| Symbol | Kind | Note |
|---|---|---|
| Slide | struct | Single photo in a slideshow; conforms to Identifiable, Equatable, Sendable |
| Slide.id | property (let UUID) | Unique identifier |
| Slide.localIdentifier | property (let String) | Photos library local identifier for the image asset |
| Slide.order | property (var Int) | Position within its parent slideshow |
| Slide.duration | property (var TimeInterval) | Display duration in seconds |
| Slide.title | property (var String?) | Optional user-assigned title |

## `Slideshow.swift`

| Symbol | Kind | Note |
|---|---|---|
| Slideshow | struct | Ordered collection of slides; conforms to Identifiable, Equatable, Sendable |
| Slideshow.id | property (let UUID) | Unique identifier |
| Slideshow.name | property (var String) | User-visible slideshow name |
| Slideshow.slides | property (var [Slide]) | Ordered array of slides in this slideshow |
| Slideshow.createdAt | property (var Date) | Timestamp when the slideshow was created |
