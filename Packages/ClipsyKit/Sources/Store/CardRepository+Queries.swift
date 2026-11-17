import GRDB

public extension CardRepository {
    @concurrent
    func cards(in list: CardList) async throws -> [CardSummary] {
        try await database.pool.read { connection in
            try Self.fetchCards(in: list, from: connection)
        }
    }

    @concurrent
    func cards(withIDs ids: [Int64]) async throws -> [CardSummary] {
        guard ids.isEmpty == false else { return [] }
        return try await database.pool.read { connection in
            try CardSummary.fetchAll(
                connection,
                sql: CardSummary.selection + "\nWHERE card.id IN (\(databaseQuestionMarks(count: ids.count)))",
                arguments: StatementArguments(ids)
            )
        }
    }

    @concurrent
    func card(at offset: Int, in list: CardList) async throws -> CardSummary? {
        try await database.pool.read { connection in
            try Self.fetchCards(in: list, from: connection, page: (limit: 1, offset: offset)).first
        }
    }

    @concurrent
    func latestCard(of kind: CardKind) async throws -> CardSummary? {
        try await database.pool.read { connection in
            try CardSummary.fetchOne(
                connection,
                sql: CardSummary.selection
                    + "\nWHERE card.last_copied_at IS NOT NULL AND card.kind = ?\n" + Self.historyOrder + "\nLIMIT 1",
                arguments: [kind.rawValue]
            )
        }
    }

    func observeCards(in list: CardList) -> some AsyncSequence<[CardSummary], any Error> & Sendable {
        ValueObservation
            .tracking { connection in try Self.fetchCards(in: list, from: connection) }
            .removeDuplicates()
            .values(in: database.pool, bufferingPolicy: .bufferingNewest(1))
    }

    private static let historyOrder = "ORDER BY card.last_copied_at DESC, card.id DESC"

    private static func fetchCards(
        in list: CardList,
        from connection: Database,
        page: (limit: Int, offset: Int)? = nil
    ) throws -> [CardSummary] {
        var (sql, arguments): (String, StatementArguments) = switch list {
        case .history:
            ("WHERE card.last_copied_at IS NOT NULL\n" + historyOrder, [])
        case let .board(id):
            ("WHERE card.board_id = ?\nORDER BY card.board_position, card.id", [id])
        }
        if let page {
            sql += "\nLIMIT ? OFFSET ?"
            arguments += [page.limit, page.offset]
        }
        return try CardSummary.fetchAll(connection, sql: CardSummary.selection + "\n" + sql, arguments: arguments)
    }
}
