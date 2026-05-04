import Foundation

protocol ConfigDataSourceProtocol: Sendable {
    func load() async throws -> ConfigDTO?
    func save(_ dto: ConfigDTO) async throws
}
