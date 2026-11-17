import Foundation
import GRDB

public extension CardRepository {
    @concurrent
    func storageSummary() async throws -> StorageSummary {
        let cardCount = try await database.pool.read { connection in
            try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM card") ?? 0
        }
        let databaseFiles = ["clipsy.sqlite", "clipsy.sqlite-wal", "clipsy.sqlite-shm"].map {
            database.directory.appending(path: $0, directoryHint: .notDirectory)
        }
        let byteCount = try (databaseFiles + payloads.allFiles()).reduce(Int64(0)) { total, file in
            // the -wal and -shm files do not always exist
            guard let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]) else { return total }
            return total + Int64(values.totalFileAllocatedSize ?? 0)
        }
        return StorageSummary(cardCount: cardCount, byteCount: byteCount)
    }
}
