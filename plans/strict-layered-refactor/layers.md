# Layer Manifest

plan: strict-layered-refactor

| Order | Layer | Spec | Summary |
|-------|-------|------|---------|
| 1 | Domain/Services | domain-services.md | 4 new service protocols + implementations |
| 2 | UseCases/Requests | usecases-requests.md | UseCaseRequest protocol + 14 request structs |
| 3 | UseCases/Responses | usecases-responses.md | 5 response structs + 2 response enums |
| 4 | UseCases | usecases.md | 14 use cases refactored to Request→DomainService→Response |
| 5 | Presentation | presentation.md | ViewModels refactored to use Response types |
| 6 | DI | di.md | DomainContainer + updated boot order |
| 7 | Rules | rules.md | arch rule updates + SwiftLint changes |
