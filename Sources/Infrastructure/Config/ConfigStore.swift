import Foundation
import Yams

final class ConfigStore: ConfigDataSourceProtocol {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> ConfigDTO {
        let fileURL = self.fileURL
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    continuation.resume(returning: ConfigDTO(duration: "5", transition: "fade", loop: true))
                    return
                }
                do {
                    let data = try Data(contentsOf: fileURL)
                    let yaml = String(decoding: data, as: UTF8.self)
                    let dto = try YAMLDecoder().decode(ConfigDTO.self, from: yaml)
                    continuation.resume(returning: dto)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func save(_ dto: ConfigDTO) async throws {
        let fileURL = self.fileURL
        let directory = fileURL.deletingLastPathComponent()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    let yaml = try YAMLEncoder().encode(dto)
                    try Data(yaml.utf8).write(to: fileURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
