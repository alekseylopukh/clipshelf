import GRDB

public extension CardRepository {
    @concurrent
    func cards(in list: CardList) async throws -> [CardSummary] {
        try await database.pool.read { connection in
            try Self.fetchCards(in: list, from: connection)
        }
    }

    func observeCards(in list: CardList) -> some AsyncSequence<[CardSummary], any Error> & Sendable {
        ValueObservation
            .tracking { connection in try Self.fetchCards(in: list, from: connection) }
            .removeDuplicates()
            .values(in: database.pool, bufferingPolicy: .bufferingNewest(1))
    }

    private static func fetchCards(in list: CardList, from connection: Database) throws -> [CardSummary] {
        switch list {
        case .history:
            try CardSummary.fetchAll(
                connection,
                sql: CardSummary.selection + """

                WHERE card.last_copied_at IS NOT NULL
                ORDER BY card.last_copied_at DESC, card.id DESC
                """
            )
        case let .board(id):
            try CardSummary.fetchAll(
                connection,
                sql: CardSummary.selection + """

                WHERE card.board_id = ?
                ORDER BY card.board_position, card.id
                """,
                arguments: [id]
            )
        }
    }
}
