# DI Layer (modified)

Boot order changes from 4-stage to 5-stage:
```
Infrastructure → Repositories → Domain → UseCases → Presentation
```

---

## `Sources/DI/DomainContainer.swift` (new)

```swift
final class DomainContainer: Sendable {
    let slideshowService: any SlideshowDomainServiceProtocol
    let imageService: any ImageDomainServiceProtocol
    let configService: any ConfigDomainServiceProtocol
    let playbackService: any PlaybackDomainServiceProtocol

    init(repositories: RepositoryContainer) {
        slideshowService = SlideshowDomainService(
            repository: repositories.slideshowRepository
        )
        imageService = ImageDomainService(
            repository: repositories.imageRepository
        )
        configService = ConfigDomainService(
            repository: repositories.configRepository
        )
        playbackService = PlaybackDomainService()
    }
}
```

---

## `Sources/DI/UseCaseContainer.swift` (modified)

Changes:
- `init` takes `DomainContainer` instead of `RepositoryContainer`
- All UseCase inits receive Domain Service protocols

```swift
final class UseCaseContainer: Sendable {
    let createSlideshow: any CreateSlideshowUseCaseProtocol
    let fetchSlideshow: any FetchSlideshowUseCaseProtocol
    let fetchSlideshows: any FetchSlideshowsUseCaseProtocol
    let fetchLibrary: any FetchLibraryUseCaseProtocol
    let loadSlideImage: any LoadSlideImageUseCaseProtocol
    let loadThumbnail: any LoadThumbnailUseCaseProtocol
    let loadConfig: any LoadConfigUseCaseProtocol
    let saveConfig: any SaveConfigUseCaseProtocol
    let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
    let advanceSlide: any AdvanceSlideUseCaseProtocol
    let setDirectory: any SetDirectoryUseCaseProtocol
    let addDroppedFiles: any AddDroppedFilesUseCaseProtocol
    let deleteSlideshow: any DeleteSlideshowUseCaseProtocol
    let updateSlideshow: any UpdateSlideshowUseCaseProtocol

    init(domain: DomainContainer) {
        createSlideshow = CreateSlideshowUseCase(
            domainService: domain.slideshowService
        )
        fetchSlideshow = FetchSlideshowUseCase(
            domainService: domain.slideshowService
        )
        fetchSlideshows = FetchSlideshowsUseCase(
            domainService: domain.slideshowService
        )
        fetchLibrary = FetchLibraryUseCase(
            domainService: domain.imageService
        )
        loadSlideImage = LoadSlideImageUseCase(
            domainService: domain.imageService
        )
        loadThumbnail = LoadThumbnailUseCase(
            domainService: domain.imageService
        )
        loadConfig = LoadConfigUseCase(
            domainService: domain.configService
        )
        saveConfig = SaveConfigUseCase(
            domainService: domain.configService
        )
        updateSlideshowConfig = UpdateSlideshowConfigUseCase(
            domainService: domain.slideshowService,
            playbackService: domain.playbackService
        )
        advanceSlide = AdvanceSlideUseCase(
            domainService: domain.playbackService
        )
        setDirectory = SetDirectoryUseCase(
            domainService: domain.imageService
        )
        addDroppedFiles = AddDroppedFilesUseCase(
            domainService: domain.imageService
        )
        deleteSlideshow = DeleteSlideshowUseCase(
            domainService: domain.slideshowService
        )
        updateSlideshow = UpdateSlideshowUseCase(
            domainService: domain.slideshowService
        )
    }
}
```

---

## `Sources/DI/Container.swift` (modified)

```swift
final class Container {
    let infrastructure: InfrastructureContainer
    let repositories: RepositoryContainer
    let domain: DomainContainer
    let useCases: UseCaseContainer
    let presentation: PresentationContainer

    init() throws {
        infrastructure = try InfrastructureContainer()
        repositories = RepositoryContainer(infrastructure: infrastructure)
        domain = DomainContainer(repositories: repositories)
        useCases = UseCaseContainer(domain: domain)
        presentation = PresentationContainer(useCases: useCases)
    }
}
```

---

## `Sources/DI/RepositoryContainer.swift` (unchanged)

No changes — still receives `InfrastructureContainer`, exposes repository protocols.

## `Sources/DI/InfrastructureContainer.swift` (unchanged)

No changes.

## `Sources/DI/PresentationContainer.swift` (unchanged structurally)

Still receives `UseCaseContainer`. No structural change, but ViewModel factories will pass `SlideshowResponse` instead of `Slideshow` where applicable.
