import Foundation
import GRDB

public extension CardRepository {
    @concurrent
    func rename(card id: Int64, to title: String) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = trimmed.isEmpty ? nil : trimmed
        try await database.pool.write { connection in
            try connection.execute(sql: "UPDATE card SET title = ? WHERE id = ?", arguments: [stored, id])
            try Self.requireChange(in: connection, table: "card", id: id)
            try connection.execute(sql: "UPDATE card_search SET title = ? WHERE rowid = ?", arguments: [stored, id])
        }
    }
}
