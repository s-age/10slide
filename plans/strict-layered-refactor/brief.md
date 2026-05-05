# Goal

Refactor from Clean Architecture's flexible V-shape (UseCase → Entity & Repository) to a strict one-way layered architecture: **Presentation → UseCase → Domain Service → Repository → Infrastructure**. This eliminates ambiguity about where Repository orchestration belongs, makes layer violation detection mechanically trivial, and ensures Presentation never touches Domain internals.

# Key Design Decisions

- **Domain Services introduced**: `Sources/Domain/Services/` houses orchestrators that own Repository calls. Domain/Entities remains pure value types (Foundation-only). Domain/Services may import Repository protocols.
- **UseCase Request/Response boundary**: All UseCase inputs are `UseCaseRequest`-conforming structs (with `validate()`). All UseCase outputs returning domain concepts use Response structs. Presentation never imports Domain types.
- **Playback logic stays pure**: `AdvanceSlide` and config transforms remain pure computation — Domain Service receives relevant scalars, no unnecessary repository fetch.
- **Empty requests still required**: Even parameterless UseCases take a request struct (e.g. `FetchSlideshowsRequest`) to maintain uniform dispatch.
- **DomainContainer added**: Boot order becomes Infra → Repo → Domain → UseCase → Presentation. Domain Services receive Repository protocols via DI.
- **SwiftLint rule updated**: Presentation prohibited from importing Domain/Entities. New `arch-domain-services.md` rule file allows Domain/Services to import Repository/Protocols.
- **Enum duplication accepted**: `SlideDuration` and `TransitionType` are duplicated as Response enums in UseCase layer. Mapping happens in UseCase. This is the cost of strict isolation.
