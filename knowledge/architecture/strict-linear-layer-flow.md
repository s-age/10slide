---
type: decision
context: choosing between Clean Architecture V-shape and strict linear layer flow
keywords: [architecture, clean-architecture, layered, domain-service, repository, usecase]
---

## What

The project uses a strict linear layer flow (UseCase → Domain Service → Repository → Infrastructure) instead of the classic Clean Architecture V-shape where UseCases fan out to both Entities and Repositories. The linear model eliminates ambiguity about where Repository orchestration belongs and makes violations mechanically detectable by SwiftLint and AI code generation tools.

## Do

- Route all calls through each layer's immediate neighbor only
- Place Repository orchestration in Domain Services, not UseCases
- Rely on SwiftLint custom rules to enforce the single-direction flow

## Don't

- Allow UseCases to call Repository protocols directly
- Skip layers (e.g., Presentation calling Domain Services)
- Introduce V-shape fanout even when a UseCase "only needs one thing" from the repository
