# UseCase Catalog
Updated: 2026-05-03

Layer path: `Sources/UseCases/`

No use case source files exist yet. The UseCaseContainer is defined in `Sources/DI/UseCaseContainer.swift` and accepts a RepositoryContainer, but no use case classes or protocols have been created.

When use cases are added they should follow this layout:

```
UseCases/
  Protocols/    — *UseCaseProtocol contracts consumed by Presentation
  Implementations/ — concrete use case classes
```
