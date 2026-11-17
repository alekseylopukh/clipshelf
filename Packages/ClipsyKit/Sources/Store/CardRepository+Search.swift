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
        guard let request = Self.searchRequest(query, filter: filter, now: now, calendar: calendar) else { return [] }
        let cards = try await database.pool.read { connection in
            try request.fetchAll(connection)
        }
        return Self.results(cards, query: query)
    }

    func observeSearch(
        _ text: String,
        filter: CardFilter = CardFilter()
    ) -> some AsyncSequence<[SearchResult], any Error> & Sendable {
        let query = SearchQuery(text)
        let request = Self.searchRequest(query, filter: filter, now: .now, calendar: .current)
        return ValueObservation
            .tracking { connection in
                try Self.results(request?.fetchAll(connection) ?? [], query: query)
            }
            .removeDuplicates()
            .values(in: database.pool, bufferingPolicy: .bufferingNewest(1))
    }

    func observeSourceApps() -> some AsyncSequence<[SourceApp], any Error> & Sendable {
        ValueObservation
            .tracking { connection in
                try Row.fetchAll(connection, sql: """
                SELECT bundle_id, name FROM source_app
                WHERE EXISTS (SELECT 1 FROM card WHERE card.source_app_id = source_app.id)
                """)
                .map { SourceApp(bundleID: $0["bundle_id"], name: $0["name"]) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            }
            .removeDuplicates()
            .values(in: database.pool, bufferingPolicy: .bufferingNewest(1))
    }

    private static func searchRequest(
        _ query: SearchQuery,
        filter: CardFilter,
        now: Date,
        calendar: Calendar
    ) -> SQLRequest<CardSummary>? {
        var conditions: [SQL] = []
        if let pattern = query.ftsPattern {
            conditions.append("card.id IN (SELECT rowid FROM card_search WHERE card_search MATCH \(pattern))")
        } else if filter.isEmpty {
            return nil
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
        return SQLRequest<CardSummary>(literal: [
            SQL(sql: CardSummary.selection),
            "WHERE " + conditions.joined(separator: " AND "),
            "ORDER BY coalesce(card.last_copied_at, card.created_at) DESC, card.id DESC"
        ].joined(separator: "\n"))
    }

    private static func results(_ cards: [CardSummary], query: SearchQuery) -> [SearchResult] {
        cards.map { card in
            SearchResult(
                card: card,
                titleMatches: card.title.map(query.matches(in:)) ?? [],
                previewMatches: card.preview.map(query.matches(in:)) ?? []
            )
        }
    }
}
