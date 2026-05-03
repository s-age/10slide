# Layer Manifest

plan: slideshow-playback

| Order | Layer | Spec | Summary |
|-------|-------|------|---------|
| 1 | Domain | domain.md | 2 new entities (`SlideshowConfig`, `TransitionType`), 1 modified (`Slideshow`) |
| 2 | Infrastructure | infrastructure.md | 1 new actor (`ConfigStore`), 1 new data source (`SlideshowDataSource`), 1 new DTO (`ConfigDTO`), 2 new protocols, 1 modified DTO (`SlideshowModel`) |
| 3 | Repositories | repositories.md | 3 new protocols, 3 new implementations (`ConfigRepository`, `SlideshowRepository`, `ImageRepository`) |
| 4 | UseCases | usecases.md | 6 new use cases |
| 5 | Presentation | presentation.md | 2 ViewModels, 3 Views |
| 6 | DI | di.md | 4 container modifications |
