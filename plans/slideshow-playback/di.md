# DI Layer

## `Sources/DI/InfrastructureContainer.swift` (modified)

**Change**: Add `slideshowDataSource` and `configDataSource`.

```swift
import SwiftData

final class InfrastructureContainer {
    let modelContainer: ModelContainer
    let imageDataSource: any ImageDataSourceProtocol
    let slideDataSource: any SlideDataSourceProtocol
    let slideshowDataSource: any SlideshowDataSourceProtocol
    let configDataSource: any ConfigDataSourceProtocol

    init() throws {
        modelContainer = try ModelContainer(for: SlideModel.self, SlideshowModel.self)
        imageDataSource = ImageDataSource()
        slideDataSource = SlideDataSource(container: modelContainer)
        slideshowDataSource = SlideshowDataSource(container: modelContainer)

        let configDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("10slide", isDirectory: true)
        let configURL = configDir.appendingPathComponent("config.yml")
        configDataSource = ConfigStore(fileURL: configURL)
    }
}
```

## `Sources/DI/RepositoryContainer.swift` (modified)

**Change**: Add `slideshowRepository`, `configRepository`, `imageRepository`.

```swift
final class RepositoryContainer {
    let slideRepository: any SlideRepositoryProtocol
    let slideshowRepository: any SlideshowRepositoryProtocol
    let configRepository: any ConfigRepositoryProtocol
    let imageRepository: any ImageRepositoryProtocol

    init(infrastructure: InfrastructureContainer) {
        slideRepository = SlideRepository(
            slideDataSource: infrastructure.slideDataSource,
            imageDataSource: infrastructure.imageDataSource
        )
        slideshowRepository = SlideshowRepository(
            slideshowDataSource: infrastructure.slideshowDataSource,
            slideDataSource: infrastructure.slideDataSource
        )
        configRepository = ConfigRepository(
            configDataSource: infrastructure.configDataSource
        )
        imageRepository = ImageRepository(
            imageDataSource: infrastructure.imageDataSource
        )
    }
}
```

## `Sources/DI/UseCaseContainer.swift` (modified)

**Change**: Add all 6 use cases.

```swift
final class UseCaseContainer {
    let createSlideshow: CreateSlideshowUseCase
    let fetchSlideshow: FetchSlideshowUseCase
    let fetchLibrary: FetchLibraryUseCase
    let loadSlideImage: LoadSlideImageUseCase
    let loadConfig: LoadConfigUseCase
    let saveConfig: SaveConfigUseCase

    init(repositories: RepositoryContainer) {
        createSlideshow = CreateSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository,
            configRepository: repositories.configRepository
        )
        fetchSlideshow = FetchSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository
        )
        fetchLibrary = FetchLibraryUseCase(
            imageRepository: repositories.imageRepository
        )
        loadSlideImage = LoadSlideImageUseCase(
            imageRepository: repositories.imageRepository
        )
        loadConfig = LoadConfigUseCase(
            configRepository: repositories.configRepository
        )
        saveConfig = SaveConfigUseCase(
            configRepository: repositories.configRepository
        )
    }
}
```

## `Sources/DI/PresentationContainer.swift` (modified)

**Change**: Add ViewModel factory methods.

```swift
final class PresentationContainer {
    private let useCases: UseCaseContainer

    init(useCases: UseCaseContainer) {
        self.useCases = useCases
    }

    @MainActor
    func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
        LibraryPickerViewModel(
            fetchLibrary: useCases.fetchLibrary,
            createSlideshow: useCases.createSlideshow
        )
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: Slideshow) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(
            slideshow: slideshow,
            loadSlideImage: useCases.loadSlideImage
        )
    }
}
```
