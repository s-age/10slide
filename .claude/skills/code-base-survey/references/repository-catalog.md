# Repository Catalog
Updated: 2026-05-03

Layer path: `Sources/Repositories/`

## `Protocols/SlideRepositoryProtocol.swift`

| Symbol | Kind | Note |
|---|---|---|
| SlideRepositoryProtocol | protocol | Contract for slide CRUD operations; conforms to Sendable |
| fetchAll() | func | Returns all slides as domain [Slide] entities |
| save(_:in:) | func | Persists a Slide within a given slideshow (by UUID) |
| delete(id:) | func | Deletes a slide by its UUID |

## `Implementations/SlideRepository.swift`

| Symbol | Kind | Note |
|---|---|---|
| SlideRepository | final class | Concrete implementation of SlideRepositoryProtocol |
| SlideRepository.slideDataSource | property (private let any SlideDataSourceProtocol) | Injected slide persistence adapter |
| SlideRepository.imageDataSource | property (private let any ImageDataSourceProtocol) | Injected image data adapter |
| SlideRepository.init(slideDataSource:imageDataSource:) | init | Accepts both data source protocols via DI |
| fetchAll() | func | Fetches SlideModels from data source and maps to domain Slide entities |
| save(_:in:) | func | Converts domain Slide to SlideModel and delegates to data source |
| delete(id:) | func | Delegates deletion to slide data source by UUID |
