# Protocol Typealias Template

File: `Sources/UseCases/Protocols/{{Name}}UseCaseProtocol.swift`

## Async use case

```swift
typealias {{Name}}UseCaseProtocol = any AsyncUseCase<{{Name}}Request, {{ResponseType}}>
```

## Sync use case

```swift
typealias {{Name}}UseCaseProtocol = any SyncUseCase<{{Name}}Request, {{ResponseType}}>
```

## Rules

- One typealias per file — file name matches the typealias name
- Always use `any` prefix (existential type) — it is embedded in the typealias so consumers never add `any` again
- `{{ResponseType}}` is the concrete return type: a Response struct (`SlideshowResponse`), primitive (`[String]`, `Int?`), or `Void`
- Never create a standalone `protocol` — the base generic protocols (`AsyncUseCase`, `SyncUseCase`) already provide the contract
- Presentation and DI layers reference `{{Name}}UseCaseProtocol` directly without `any` prefix
