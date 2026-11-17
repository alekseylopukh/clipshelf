import Foundation
import GRDB

public extension CardRepository {
    /// board cards older than the cutoff leave History; other cards older than it are deleted
    @concurrent
    func purge(olderThan cutoff: Date) async throws {
        try await removeHistory(before: cutoff.timeIntervalSince1970)
    }

    @concurrent
    func eraseHistory() async throws {
        try await removeHistory(before: .infinity)
    }

    private func removeHistory(before cutoff: Double) async throws {
        try await database.pool.write { connection in
            try connection.execute(
                sql: "UPDATE card SET last_copied_at = NULL WHERE board_id IS NOT NULL AND last_copied_at < ?",
                arguments: [cutoff]
            )
            let expired: SQL = "SELECT id FROM card WHERE board_id IS NULL AND last_copied_at < \(cutoff)"
            try connection.execute(literal: "DELETE FROM card_search WHERE rowid IN (\(expired))")
            try connection.execute(literal: "DELETE FROM card WHERE id IN (\(expired))")
        }
        try await collectGarbage()
    }

    private func collectGarbage() async throws {
        // runs on the writer so record() cannot store a payload between reading references and deleting files
        try await database.pool.writeWithoutTransaction { [payloads] connection in
            let payloadHashes = try String.fetchSet(
                connection,
                sql: "SELECT payload_hash FROM representation WHERE payload_hash IS NOT NULL"
            )
            let contentHashes = try String.fetchSet(connection, sql: "SELECT lower(hex(content_hash)) FROM card")
            try payloads.collectGarbage(payloads: payloadHashes, thumbnails: contentHashes)
        }
    }
}
