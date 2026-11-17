import GRDB

public extension CardRepository {
    @concurrent
    func search(_ text: String) async throws -> [SearchResult] {
        let query = SearchQuery(text)
        guard let pattern = query.ftsPattern else { return [] }
        let cards = try await database.pool.read { connection in
            try CardSummary.fetchAll(
                connection,
                sql: CardSummary.selection + """

                JOIN card_search ON card_search.rowid = card.id
                WHERE card_search MATCH ?
                ORDER BY coalesce(card.last_copied_at, card.created_at) DESC, card.id DESC
                """,
                arguments: [pattern]
            )
        }
        return cards.map { card in
            SearchResult(
                card: card,
                titleMatches: card.title.map(query.matches(in:)) ?? [],
                previewMatches: card.preview.map(query.matches(in:)) ?? []
            )
        }
    }
}
