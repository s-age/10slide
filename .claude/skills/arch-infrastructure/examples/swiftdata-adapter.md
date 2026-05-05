# Example: SwiftData Adapter

The generic `@ModelActor` store that all SwiftData-backed repositories share. Normally this already exists — extend rather than duplicate.

## Existing files

### Protocol — `Sources/Infrastructure/Protocols/SwiftDataStoreProtocol.swift`

```swift
import Foundation
import SwiftData

protocol SwiftDataStoreProtocol: Sendable {
    func fetch<T: PersistentModel, R: Sendable>(
        _ descriptor: FetchDescriptor<T>,
        transform: @Sendable (T) throws -> R
    ) async throws -> [R]

    func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) async throws

    func write(_ work: @Sendable (ModelContext) throws -> Void) async throws
}
```

### Implementation — `Sources/Infrastructure/SwiftData/SwiftDataStore.swift`

```swift
import Foundation
import SwiftData

@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol {
    func fetch<T: PersistentModel, R: Sendable>(
        _ descriptor: FetchDescriptor<T>,
        transform: @Sendable (T) throws -> R
    ) throws -> [R] {
        try modelContext.fetch(descriptor).map(transform)
    }

    func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws {
        try modelContext.delete(model: type, where: predicate)
        try modelContext.save()
    }

    func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
        try work(modelContext)
    }
}
```

## Key points

- `@ModelActor` synthesizes `init(modelContainer:)` and pins all work to one executor
- Generic over `PersistentModel` — concrete `@Model` types live in `Repositories/Models/`
- `transform` closure maps `@Model` → `Sendable` value type inside the actor, avoiding cross-actor model access
- Protocol methods are `async throws` but actor implementations drop `async` (actor isolation handles it)
- Never wrap `ModelContext` in a `Mutex` — it is not thread-safe
