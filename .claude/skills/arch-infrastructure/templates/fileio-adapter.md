# File I/O Adapter Template

File: `Sources/Infrastructure/{{Subdirectory}}/{{Name}}Store.swift`

For adapters that perform file I/O, YAML/JSON parsing, network requests, or other non-framework I/O.

```swift
import Foundation
import {{SerializationLibrary}}  // e.g. Yams, or omit if using Foundation's JSONDecoder

final class {{Name}}Store: {{Name}}DataSourceProtocol {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> {{Name}}DTO? {
        let fileURL = self.fileURL
        return try await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            let data = try Data(contentsOf: fileURL)
            return try {{Decoder}}().decode({{Name}}DTO.self, from: data)
        }.value
    }

    func save(_ dto: {{Name}}DTO) async throws {
        let fileURL = self.fileURL
        let directory = fileURL.deletingLastPathComponent()
        try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoded = try {{Encoder}}().encode(dto)
            try Data(encoded.utf8).write(to: fileURL, options: .atomic)
        }.value
    }
}
```

## Rules

- `final class` — not `@ModelActor`
- Capture `self.fileURL` as local `let` before `Task.detached` — avoid capturing `self`
- All file I/O inside `Task.detached` — never on the cooperative pool
- `.utility` priority for background persistence; `.userInitiated` for user-facing loads
- Return `nil` for missing file — let Repository decide defaults
- Atomic write via `.atomic` option
- DTO is `Codable` + `Sendable`
