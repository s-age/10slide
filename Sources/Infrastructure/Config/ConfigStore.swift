import Foundation
import Yams

final class ConfigStore: ConfigDataSourceProtocol {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> ConfigDTO {
        let fileURL = self.fileURL
        return try await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return ConfigDTO(duration: "5", transition: "fade", loop: true)
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
            try Data(yaml.utf8).write(to: fileURL)
        }.value
    }
}
