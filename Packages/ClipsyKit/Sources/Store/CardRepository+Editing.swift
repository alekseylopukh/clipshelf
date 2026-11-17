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

    /// keeps the card's title, source app, times, History position and board; ignores `card.sourceApp`
    @concurrent
    func replaceContent(of id: Int64, with card: NewCard) async throws {
        try await database.pool.write { [payloads] connection in
            try Self.refuseDuplicate(of: card.contentHash, except: id, in: connection)
            try connection.execute(
                sql: """
                UPDATE card SET kind = ?, content_hash = ?, preview_text = ?, metadata = ?, byte_size = ?, ocr_state = 0
                WHERE id = ?
                """,
                arguments: [card.kind.rawValue, card.contentHash, card.previewText, card.metadata, card.byteSize, id]
            )
            try Self.requireChange(in: connection, table: "card", id: id)
            try connection.execute(sql: "DELETE FROM representation WHERE card_id = ?", arguments: [id])
            try Self.insert(card.representations, of: id, into: payloads, in: connection)
            try connection.execute(
                sql: "UPDATE card_search SET body = ?, url = ?, file_names = ?, ocr_text = NULL WHERE rowid = ?",
                arguments: [card.searchBody ?? card.previewText, card.url, card.joinedFileNames, id]
            )
        }
    }

    @discardableResult
    @concurrent
    func add(_ card: NewCard, to list: CardList, at date: Date = .now) async throws -> Int64 {
        try await database.pool.write { connection in
            try Self.refuseDuplicate(of: card.contentHash, except: nil, in: connection)
            let sourceAppID = try Self.upsert(card.sourceApp, in: connection)
            let time = date.timeIntervalSince1970
            let board: (id: Int64, position: Double)?
            switch list {
            case .history:
                board = nil
            case let .board(boardID):
                let front = try Double.fetchOne(
                    connection,
                    sql: "SELECT MIN(board_position) FROM card WHERE board_id = ?",
                    arguments: [boardID]
                )
                board = (boardID, (front ?? 0) - 1)
            }
            return try insertCard(card, sourceAppID: sourceAppID, at: time, board: board, in: connection)
        }
    }

    private static func refuseDuplicate(of contentHash: Data, except id: Int64?, in connection: Database) throws {
        let exists = try Bool.fetchOne(
            connection,
            sql: "SELECT EXISTS (SELECT 1 FROM card WHERE content_hash = ? AND id IS NOT ?)",
            arguments: [contentHash, id]
        ) ?? false
        if exists {
            throw CardEditError.duplicateContent
        }
    }
}
