# Infrastructure Catalog
Updated: 2026-05-03

Layer path: `Sources/Infrastructure/`

## `Protocols/ImageDataSourceProtocol.swift`

| Symbol | Kind | Note |
|---|---|---|
| ImageDataSourceProtocol | protocol | Contract for Photos library access; conforms to Sendable |
| fetchAllIdentifiers() | func | Returns all available photo asset local identifiers |
| fetchImage(localIdentifier:) | func | Fetches a single image by its local identifier; returns ImageDTO |

## `Protocols/SlideDataSourceProtocol.swift`

| Symbol | Kind | Note |
|---|---|---|
| SlideDataSourceProtocol | protocol | Contract for slide persistence via SwiftData; conforms to Sendable |
| fetchAll() | func | Returns all persisted SlideModel instances |
| save(_:) | func | Inserts or updates a SlideModel |
| delete(id:) | func | Deletes a slide by its UUID |

## `Image/DTO/ImageDTO.swift`

| Symbol | Kind | Note |
|---|---|---|
| ImageDTO | struct | Raw image transport type from Photos framework; conforms to Sendable |
| ImageDTO.localIdentifier | property (let String) | Photos library asset identifier |
| ImageDTO.data | property (let Data) | Raw image bytes |
| ImageDTO.creationDate | property (let Date?) | Optional photo creation date |

## `Image/ImageDataSource.swift`

| Symbol | Kind | Note |
|---|---|---|
| ImageDataSource | final class | Photos framework adapter; implements ImageDataSourceProtocol |
| fetchAllIdentifiers() | func | Stub returning empty array (not yet implemented) |
| fetchImage(localIdentifier:) | func | Stub calling fatalError (not yet implemented) |

## `SwiftData/DTO/SlideModel.swift`

| Symbol | Kind | Note |
|---|---|---|
| SlideModel | @Model final class | SwiftData persistence model for a single slide |
| SlideModel.id | property (var UUID) | Unique identifier; @Attribute(.unique) |
| SlideModel.localIdentifier | property (var String) | Photos asset identifier |
| SlideModel.order | property (var Int) | Sort position within slideshow |
| SlideModel.duration | property (var TimeInterval) | Display duration in seconds |
| SlideModel.title | property (var String?) | Optional slide title |
| SlideModel.slideshow | property (var SlideshowModel?) | Inverse relationship to parent slideshow |
| SlideModel.init(id:localIdentifier:order:duration:title:) | init | Initializer with defaults: id=UUID(), duration=3.0, title=nil |

## `SwiftData/DTO/SlideshowModel.swift`

| Symbol | Kind | Note |
|---|---|---|
| SlideshowModel | @Model final class | SwiftData persistence model for a slideshow |
| SlideshowModel.id | property (var UUID) | Unique identifier; @Attribute(.unique) |
| SlideshowModel.name | property (var String) | Slideshow display name |
| SlideshowModel.createdAt | property (var Date) | Creation timestamp |
| SlideshowModel.slides | property (var [SlideModel]) | Cascade-delete relationship; inverse of SlideModel.slideshow |
| SlideshowModel.init(id:name:createdAt:) | init | Initializer with defaults: id=UUID(), createdAt=Date(); slides initialized to [] |

## `SwiftData/SlideDataSource.swift`

| Symbol | Kind | Note |
|---|---|---|
| SlideDataSource | final class | SwiftData-backed implementation of SlideDataSourceProtocol |
| SlideDataSource.container | property (private let ModelContainer) | SwiftData model container injected at init |
| SlideDataSource.init(container:) | init | Accepts a ModelContainer for persistence |
| fetchAll() | func | Fetches all SlideModel instances via FetchDescriptor |
| save(_:) | func | Inserts a SlideModel and saves the context |
| delete(id:) | func | Deletes SlideModel matching the given UUID using #Predicate |

---

## DI & App

### `Sources/DI/Container.swift`

| Symbol | Kind | Note |
|---|---|---|
| Container | final class | Root DI container; boots all sub-containers in dependency order |
| Container.infrastructure | property (let InfrastructureContainer) | Infrastructure layer container |
| Container.repositories | property (let RepositoryContainer) | Repository layer container |
| Container.useCases | property (let UseCaseContainer) | Use case layer container |
| Container.presentation | property (let PresentationContainer) | Presentation layer container |
| Container.init() | init (throws) | Initializes all sub-containers in order: infrastructure, repositories, useCases, presentation |

### `Sources/DI/InfrastructureContainer.swift`

| Symbol | Kind | Note |
|---|---|---|
| InfrastructureContainer | final class | DI container for infrastructure layer dependencies |
| InfrastructureContainer.modelContainer | property (let ModelContainer) | SwiftData model container for SlideModel and SlideshowModel |
| InfrastructureContainer.imageDataSource | property (let any ImageDataSourceProtocol) | Photos framework adapter |
| InfrastructureContainer.slideDataSource | property (let any SlideDataSourceProtocol) | SwiftData slide adapter |
| InfrastructureContainer.init() | init (throws) | Creates ModelContainer and instantiates both data sources |

### `Sources/DI/RepositoryContainer.swift`

| Symbol | Kind | Note |
|---|---|---|
| RepositoryContainer | final class | DI container for repository layer dependencies |
| RepositoryContainer.slideRepository | property (let any SlideRepositoryProtocol) | Slide repository wired with infra data sources |
| RepositoryContainer.init(infrastructure:) | init | Accepts InfrastructureContainer; creates SlideRepository with injected data sources |

### `Sources/DI/UseCaseContainer.swift`

| Symbol | Kind | Note |
|---|---|---|
| UseCaseContainer | final class | DI container for use case layer dependencies |
| UseCaseContainer.init(repositories:) | init | Accepts RepositoryContainer; currently empty (no use cases defined yet) |

### `Sources/DI/PresentationContainer.swift`

| Symbol | Kind | Note |
|---|---|---|
| PresentationContainer | final class | DI container for presentation layer dependencies |
| PresentationContainer.init(useCases:) | init | Accepts UseCaseContainer; currently empty (no ViewModels defined yet) |

### `Sources/App/TenSlideApp.swift`

| Symbol | Kind | Note |
|---|---|---|
| TenSlideApp | struct (@main) | App entry point; conforms to App protocol |
| TenSlideApp.container | property (private let Container) | Root DI container initialized in init() |
| TenSlideApp.init() | init | Creates the root Container; fatalError on failure |
| TenSlideApp.body | computed property (some Scene) | WindowGroup presenting ContentView with modelContainer from infrastructure |
