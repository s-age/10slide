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
