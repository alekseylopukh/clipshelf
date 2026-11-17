import Foundation
import GRDB

public extension CardRepository {
    @concurrent
    func search(
        _ text: String,
        filter: CardFilter = CardFilter(),
        now: Date = .now,
        calendar: Calendar = .current
    ) async throws -> [SearchResult] {
        let query = SearchQuery(text)
        var conditions: [SQL] = []
        if let pattern = query.ftsPattern {
            conditions.append("card.id IN (SELECT rowid FROM card_search WHERE card_search MATCH \(pattern))")
        } else if filter.isEmpty {
            return []
        }
        if let kind = filter.kind {
            conditions.append("card.kind = \(kind.rawValue)")
        }
        if let bundleID = filter.sourceAppBundleID {
            conditions.append("source_app.bundle_id = \(bundleID)")
        }
        if let range = filter.dateRange?.interval(now: now, calendar: calendar) {
            let lower = range.lowerBound.timeIntervalSince1970
            let upper = range.upperBound.timeIntervalSince1970
            conditions.append("coalesce(card.last_copied_at, card.created_at) >= \(lower)")
            conditions.append("coalesce(card.last_copied_at, card.created_at) < \(upper)")
        }
        if let boardID = filter.boardID {
            conditions.append("card.board_id = \(boardID)")
        }
        let request = SQLRequest<CardSummary>(literal: [
            SQL(sql: CardSummary.selection),
            "WHERE " + conditions.joined(separator: " AND "),
            "ORDER BY coalesce(card.last_copied_at, card.created_at) DESC, card.id DESC"
        ].joined(separator: "\n"))
        let cards = try await database.pool.read { connection in
            try request.fetchAll(connection)
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
