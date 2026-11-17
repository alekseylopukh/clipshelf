import Foundation
import GRDB

public extension CardRepository {
    /// removes the cards from `list`; a card that is then in neither History nor a board is deleted
    @concurrent
    func delete(cards cardIDs: [Int64], in list: CardList) async throws -> DeletedCards {
        try await database.pool.write { connection in
            let selected: SQL
            let inNoOtherList: SQL
            let leave: SQL
            switch list {
            case .history:
                selected = "id IN \(cardIDs) AND last_copied_at IS NOT NULL"
                inNoOtherList = "board_id IS NULL"
                leave = "last_copied_at = NULL"
            case let .board(id):
                selected = "id IN \(cardIDs) AND board_id = \(id)"
                inNoOtherList = "last_copied_at IS NULL"
                leave = "board_id = NULL, board_position = NULL"
            }
            let cards = try Self.snapshot(of: selected, in: connection)
            let gone: SQL = "SELECT id FROM card WHERE \(selected) AND \(inNoOtherList)"
            try connection.execute(literal: "DELETE FROM card_search WHERE rowid IN (\(gone))")
            try connection.execute(literal: "DELETE FROM card WHERE id IN (\(gone))")
            try connection.execute(literal: "UPDATE card SET \(leave) WHERE \(selected)")
            return DeletedCards(list: list, cards: cards)
        }
    }

    /// returns the ids of the restored cards, which may differ from the deleted ones
    @discardableResult
    @concurrent
    func restore(_ deleted: DeletedCards) async throws -> [Int64] {
        try await database.pool.write { [payloads] connection in
            try deleted.cards.compactMap { card in
                let original = card.record
                if let id = try Int64.fetchOne(
                    connection,
                    sql: "SELECT id FROM card WHERE content_hash = ? ORDER BY id = ? DESC, last_copied_at DESC LIMIT 1",
                    arguments: [original.contentHash, original.id]
                ) {
                    try Self.restoreMembership(of: original, in: deleted.list, onto: id, in: connection)
                    return id
                }
                return try Self.reinsert(card, in: deleted.list, payloads: payloads, in: connection)
            }
        }
    }

    private static func snapshot(of selected: SQL, in connection: Database) throws -> [DeletedCards.Card] {
        try DeletedCards.CardRecord.fetchAll(connection, SQLRequest(literal: "SELECT * FROM card WHERE \(selected)"))
            .map { record in
                try DeletedCards.Card(
                    record: record,
                    representations: DeletedCards.RepresentationRecord.fetchAll(
                        connection,
                        sql: "SELECT * FROM representation WHERE card_id = ?",
                        arguments: [record.id]
                    ),
                    search: Row.fetchOne(
                        connection,
                        sql: "SELECT title, body, url, file_names, ocr_text, app_name FROM card_search WHERE rowid = ?",
                        arguments: [record.id]
                    ).map { row in
                        DeletedCards.SearchRecord(
                            title: row["title"],
                            body: row["body"],
                            url: row["url"],
                            fileNames: row["file_names"],
                            ocrText: row["ocr_text"],
                            appName: row["app_name"]
                        )
                    }
                )
            }
    }

    private static func restoreMembership(
        of original: DeletedCards.CardRecord,
        in list: CardList,
        onto id: Int64,
        in connection: Database
    ) throws {
        switch list {
        case .history:
            try connection.execute(
                sql: "UPDATE card SET last_copied_at = MAX(IFNULL(last_copied_at, ?1), ?1) WHERE id = ?2",
                arguments: [original.lastCopiedAt, id]
            )
        case let .board(boardID):
            try connection.execute(
                sql: """
                UPDATE card SET board_id = ?1, board_position = ?2
                WHERE id = ?3 AND board_id IS NULL AND EXISTS (SELECT 1 FROM board WHERE id = ?1)
                """,
                arguments: [boardID, original.boardPosition, id]
            )
        }
    }

    private static func reinsert(
        _ card: DeletedCards.Card,
        in list: CardList,
        payloads: PayloadStore,
        in connection: Database
    ) throws -> Int64? {
        let missingPayload = card.representations.contains { representation in
            guard let hash = representation.payloadHash else { return false }
            return FileManager.default
                .fileExists(atPath: payloads.fileURL(for: hash).path(percentEncoded: false)) == false
        }
        guard missingPayload == false else { return nil }

        var record = card.record
        switch list {
        case .history:
            record.boardID = nil
            record.boardPosition = nil
        case let .board(boardID):
            guard try Bool.fetchOne(
                connection,
                sql: "SELECT EXISTS (SELECT 1 FROM board WHERE id = ?)",
                arguments: [boardID]
            ) == true else { return nil }
            record.lastCopiedAt = nil
        }
        if try Bool.fetchOne(connection, sql: "SELECT EXISTS (SELECT 1 FROM card WHERE id = ?)", arguments: [record.id])
            == true
        {
            record.id = nil
        }
        try record.insert(connection)
        let id = connection.lastInsertedRowID
        for var representation in card.representations {
            representation.cardID = id
            try representation.insert(connection)
        }
        if let search = card.search {
            try connection.execute(
                sql: """
                INSERT INTO card_search (rowid, title, body, url, file_names, ocr_text, app_name)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [id, search.title, search.body, search.url, search.fileNames, search.ocrText, search.appName]
            )
        }
        return id
    }
}
