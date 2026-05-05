# SwiftData Repository Template

File: `Sources/Repositories/Implementations/{{Name}}Repository.swift`

```swift
import Foundation
import SwiftData

final class {{Name}}Repository: {{Name}}RepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    init(store: any SwiftDataStoreProtocol) {
        self.store = store
    }

    // MARK: - Fetch (transform closure)

    func fetchAll() async throws -> [{{Entity}}] {
        try await store.fetch(FetchDescriptor<{{Name}}Model>()) {
            {{Entity}}(id: $0.id, {{fieldMappings}})
        }
    }

    func fetch(id: UUID) async throws -> {{Entity}}? {
        try await store.fetch(
            FetchDescriptor<{{Name}}Model>(predicate: #Predicate { $0.id == id })
        ) {
            {{Entity}}(id: $0.id, {{fieldMappings}})
        }.first
    }

    // MARK: - Write (atomic mutation)

    func save(_ {{entity}}: {{Entity}}) async throws {
        let id = {{entity}}.id
        let {{field1}} = {{entity}}.{{field1}}
        // Extract all fields from entity before entering write closure
        try await store.write { context in
            let descriptor = FetchDescriptor<{{Name}}Model>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.{{field1}} = {{field1}}
                // Update all mutable fields
            } else {
                let model = {{Name}}Model(id: id, {{field1}}: {{field1}})
                context.insert(model)
            }
            try context.save()
        }
    }

    // MARK: - Delete (predicate-based)

    func delete(id: UUID) async throws {
        try await store.delete({{Name}}Model.self, where: #Predicate { $0.id == id })
    }
}
```

## Rules

- Extract entity fields into local `let` constants before entering `store.write` closure
- `#Predicate` captures cannot reference properties on non-Sendable types across actor boundaries
- Transform closures in `store.fetch` execute inside the actor — `@Model` stays contained
- For complex transforms, use a `private func` called inside the closure
- Upsert: fetch-then-update-or-insert inside a single `store.write` call
- Always call `context.save()` at the end of write closures
- `store.delete` auto-saves — no explicit `context.save()` needed
