# Example: File I/O Adapter (YAML Config)

An adapter that reads/writes a YAML config file via `Yams`. All file I/O is offloaded to `Task.detached`.

## Files to create

### 1. Protocol — `Sources/Infrastructure/Protocols/ConfigDataSourceProtocol.swift`

```swift
import Foundation

protocol ConfigDataSourceProtocol: Sendable {
    func load() async throws -> ConfigDTO?
    func save(_ dto: ConfigDTO) async throws
}
```

### 2. DTO — `Sources/Infrastructure/Config/DTO/ConfigDTO.swift`

```swift
import Foundation

struct ConfigDTO: Sendable, Codable {
    var duration: String
    var transition: String
    var loop: Bool
}
```

### 3. Implementation — `Sources/Infrastructure/Config/ConfigStore.swift`

```swift
import Foundation
import Yams

final class ConfigStore: ConfigDataSourceProtocol {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> ConfigDTO? {
        let fileURL = self.fileURL
        return try await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            let data = try Data(contentsOf: fileURL)
            let yaml = String(decoding: data, as: UTF8.self)
            return try YAMLDecoder().decode(ConfigDTO.self, from: yaml)
        }.value
    }

    func save(_ dto: ConfigDTO) async throws {
        let fileURL = self.fileURL
        let directory = fileURL.deletingLastPathComponent()
        try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let yaml = try YAMLEncoder().encode(dto)
            try Data(yaml.utf8).write(to: fileURL, options: .atomic)
        }.value
    }
}
```

### 4. DI wiring — add to `Sources/DI/InfrastructureContainer.swift`

```swift
let configDataSource: any ConfigDataSourceProtocol

// In init
let configURL = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("10slide/config.yml")
configDataSource = ConfigStore(fileURL: configURL)
```

## Key points

- `final class` — no `@ModelActor` needed (no SwiftData)
- All file I/O in `Task.detached(priority: .utility)` — never blocks the cooperative pool
- `self.fileURL` captured as a local `let` before entering `Task.detached` — avoids capturing `self`
- DTO is `Codable` for Yams serialization and `Sendable` for cross-actor transfer
- Returns `nil` when file does not exist — Repository decides the default value
- Atomic write via `.atomic` option
