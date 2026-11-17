import Foundation
import GRDB

public extension CardRepository {
    @concurrent
    func boards() async throws -> [Board] {
        try await database.pool.read(Self.fetchBoards)
    }

    func observeBoards() -> some AsyncSequence<[Board], any Error> & Sendable {
        ValueObservation
            .tracking(Self.fetchBoards)
            .removeDuplicates()
            .values(in: database.pool, bufferingPolicy: .bufferingNewest(1))
    }

    @discardableResult
    @concurrent
    func createBoard(named name: String, color: String, at date: Date = .now) async throws -> Int64 {
        try await database.pool.write { connection in
            let last = try Double.fetchOne(connection, sql: "SELECT MAX(position) FROM board")
            try connection.execute(
                sql: "INSERT INTO board (name, color, position, created_at) VALUES (?, ?, ?, ?)",
                arguments: [Self.boardName(name), color, (last ?? -1) + 1, date.timeIntervalSince1970]
            )
            return connection.lastInsertedRowID
        }
    }

    @concurrent
    func renameBoard(_ id: Int64, to name: String) async throws {
        try await database.pool.write { connection in
            try connection.execute(sql: "UPDATE board SET name = ? WHERE id = ?", arguments: [Self.boardName(name), id])
            try Self.requireChange(in: connection, table: "board", id: id)
        }
    }

    @concurrent
    func recolorBoard(_ id: Int64, to color: String) async throws {
        try await database.pool.write { connection in
            try connection.execute(sql: "UPDATE board SET color = ? WHERE id = ?", arguments: [color, id])
            try Self.requireChange(in: connection, table: "board", id: id)
        }
    }

    /// `previousID` nil moves the board to the front
    @concurrent
    func moveBoard(_ id: Int64, after previousID: Int64?) async throws {
        try await database.pool.write { connection in
            let siblings = try Self.positions(
                in: connection,
                sql: "SELECT id, position FROM board ORDER BY position, id"
            )
            try Self.place(id, after: previousID, among: siblings, table: "board") { id, position in
                try connection.execute(sql: "UPDATE board SET position = ? WHERE id = ?", arguments: [position, id])
            }
        }
    }

    @concurrent
    func deleteBoard(_ id: Int64) async throws {
        try await database.pool.write { connection in
            try Self.deleteBoardOnlyCards(in: connection, where: "board_id = \(id)")
            try connection.execute(
                sql: "UPDATE card SET board_id = NULL, board_position = NULL WHERE board_id = ?",
                arguments: [id]
            )
            try connection.execute(sql: "DELETE FROM board WHERE id = ?", arguments: [id])
            try Self.requireChange(in: connection, table: "board", id: id)
        }
    }

    /// puts the cards at the front of the board in the given order, moving them off any other board
    @concurrent
    func addCards(_ cardIDs: [Int64], toBoard boardID: Int64) async throws {
        try await database.pool.write { connection in
            let front = try SQLRequest<Double>(
                literal: "SELECT MIN(board_position) FROM card WHERE board_id = \(boardID) AND id NOT IN \(cardIDs)"
            ).fetchOne(connection) ?? 0
            for (index, cardID) in cardIDs.enumerated() {
                try connection.execute(
                    sql: "UPDATE card SET board_id = ?, board_position = ? WHERE id = ?",
                    arguments: [boardID, front - Double(cardIDs.count - index), cardID]
                )
                try Self.requireChange(in: connection, table: "card", id: cardID)
            }
        }
    }

    /// cards that are no longer in History are deleted
    @concurrent
    func removeCardsFromBoard(_ cardIDs: [Int64]) async throws {
        try await database.pool.write { connection in
            try Self.deleteBoardOnlyCards(in: connection, where: "id IN \(cardIDs)")
            try connection.execute(
                literal: "UPDATE card SET board_id = NULL, board_position = NULL WHERE id IN \(cardIDs)"
            )
        }
    }

    /// `previousID` nil moves the card to the front of its board
    @concurrent
    func moveCard(_ id: Int64, after previousID: Int64?) async throws {
        try await database.pool.write { connection in
            guard let boardID = try Int64.fetchOne(
                connection,
                sql: "SELECT board_id FROM card WHERE id = ? AND board_id IS NOT NULL",
                arguments: [id]
            ) else { throw Self.notFound(table: "card", id: id) }
            let siblings = try Self.positions(
                in: connection,
                sql: "SELECT id, board_position FROM card WHERE board_id = ? ORDER BY board_position, id",
                arguments: [boardID]
            )
            try Self.place(id, after: previousID, among: siblings, table: "card") { id, position in
                try connection.execute(
                    sql: "UPDATE card SET board_position = ? WHERE id = ?",
                    arguments: [position, id]
                )
            }
        }
    }

    private static func fetchBoards(_ connection: Database) throws -> [Board] {
        try Board.fetchAll(connection, sql: "SELECT * FROM board ORDER BY position, id")
    }

    private static func boardName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled", comment: "Name of a board created without one") : trimmed
    }

    private static func deleteBoardOnlyCards(in connection: Database, where condition: SQL) throws {
        let boardOnly: SQL = "SELECT id FROM card WHERE \(condition) AND board_id IS NOT NULL AND last_copied_at IS NULL"
        try connection.execute(literal: "DELETE FROM card_search WHERE rowid IN (\(boardOnly))")
        try connection.execute(literal: "DELETE FROM card WHERE id IN (\(boardOnly))")
    }

    private static func positions(
        in connection: Database,
        sql: String,
        arguments: StatementArguments = []
    ) throws -> [(id: Int64, position: Double)] {
        try Row.fetchAll(connection, sql: sql, arguments: arguments).map { ($0[0], $0[1]) }
    }

    private static func place(
        _ id: Int64,
        after previousID: Int64?,
        among positions: [(id: Int64, position: Double)],
        table: String,
        update: (Int64, Double) throws -> Void
    ) throws {
        guard positions.contains(where: { $0.id == id }) else { throw notFound(table: table, id: id) }
        var siblings = positions.filter { $0.id != id }
        if let position = try position(after: previousID, among: siblings, table: table) {
            try update(id, position)
            return
        }
        for index in siblings.indices {
            siblings[index].position = Double(index)
            try update(siblings[index].id, Double(index))
        }
        guard let position = try position(after: previousID, among: siblings, table: table) else {
            fatalError("whole-number positions always leave room between neighbors")
        }
        try update(id, position)
    }

    /// nil when the neighbors are too close to fit a position between them
    private static func position(
        after previousID: Int64?,
        among siblings: [(id: Int64, position: Double)],
        table: String
    ) throws -> Double? {
        guard let previousID else { return (siblings.first?.position ?? 1) - 1 }
        guard let index = siblings.firstIndex(where: { $0.id == previousID }) else {
            throw notFound(table: table, id: previousID)
        }
        let previous = siblings[index].position
        guard index + 1 < siblings.count else { return previous + 1 }
        let next = siblings[index + 1].position
        let middle = (previous + next) / 2
        return previous < middle && middle < next ? middle : nil
    }

    internal static func requireChange(in connection: Database, table: String, id: Int64) throws {
        guard connection.changesCount > 0 else { throw notFound(table: table, id: id) }
    }

    private static func notFound(table: String, id: Int64) -> RecordError {
        .recordNotFound(databaseTableName: table, key: ["id": id.databaseValue])
    }
}
