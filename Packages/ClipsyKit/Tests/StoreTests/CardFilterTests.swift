import Foundation
import GRDB
import Testing
@testable import Store

struct CardFilterTests {
    struct Case: Sendable, CustomTestStringConvertible {
        var text = ""
        var filter: CardFilter
        var expected: [String]

        var testDescription: String {
            "\(text.isEmpty ? "" : "\"\(text)\" ")\(filter) -> \(expected)"
        }
    }

    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test(arguments: [
        Case(filter: CardFilter(kind: .text), expected: ["alpha", "gamma", "epsilon"]),
        Case(filter: CardFilter(sourceAppBundleID: browser.bundleID), expected: ["beta", "gamma"]),
        Case(filter: CardFilter(dateRange: .today), expected: ["alpha"]),
        Case(filter: CardFilter(dateRange: .yesterday), expected: ["beta"]),
        Case(filter: CardFilter(dateRange: .last7Days), expected: ["alpha", "beta", "gamma"]),
        Case(filter: CardFilter(dateRange: .last30Days), expected: ["alpha", "beta", "gamma", "delta"]),
        Case(
            filter: CardFilter(dateRange: .custom(from: daysAgo(3), through: daysAgo(20))),
            expected: ["gamma", "delta"]
        ),
        Case(filter: CardFilter(boardID: 1), expected: ["beta", "gamma"]),
        Case(filter: CardFilter(kind: .text, sourceAppBundleID: browser.bundleID), expected: ["gamma"]),
        Case(filter: CardFilter(kind: .text, dateRange: .last7Days, boardID: 1), expected: ["gamma"]),
        Case(filter: CardFilter(kind: .text, boardID: 2), expected: []),
        Case(text: "note", filter: CardFilter(kind: .text), expected: ["alpha", "gamma"]),
        Case(
            text: "note",
            filter: CardFilter(sourceAppBundleID: editor.bundleID, dateRange: .last30Days),
            expected: ["alpha", "delta"]
        ),
        Case(text: "beta", filter: CardFilter(boardID: 2), expected: [])
    ])
    func `filters combine with and`(testCase: Case) async throws {
        var names: [Int64: String] = [:]
        try await names[record("alpha note", kind: .text, app: Self.editor, at: Self.now - 3600)] = "alpha"
        try await names[record("beta note", kind: .link, app: Self.browser, at: Self.daysAgo(1))] = "beta"
        try await names[record("gamma note", kind: .text, app: Self.browser, at: Self.daysAgo(3))] = "gamma"
        try await names[record("delta note", kind: .image, app: Self.editor, at: Self.daysAgo(20))] = "delta"
        try await names[record("epsilon", kind: .text, app: Self.editor, at: Self.daysAgo(40))] = "epsilon"
        try await database.pool.write { connection in
            try connection.execute(sql: """
            INSERT INTO board (id, name, color, position, created_at) VALUES (1, 'One', 'blue', 1, 0), (2, 'Two', 'red', 2, 0);
            UPDATE card SET board_id = 1, board_position = id WHERE preview_text IN ('beta note', 'gamma note');
            UPDATE card SET board_id = 2, board_position = 1 WHERE preview_text = 'delta note';
            """)
        }

        let results = try await repository.search(
            testCase.text,
            filter: testCase.filter,
            now: Self.now,
            calendar: Self.utc
        )

        #expect(results.compactMap { names[$0.id] } == testCase.expected)
    }

    @Test func `board only cards are dated by creation`() async throws {
        let id = try await record("note", kind: .text, app: Self.editor, at: Self.now - 60)
        try await database.pool.write { connection in
            try connection
                .execute(sql: "INSERT INTO board (id, name, color, position, created_at) VALUES (1, 'B', 'blue', 1, 0)")
            try connection.execute(
                sql: "UPDATE card SET board_id = 1, board_position = 1, last_copied_at = NULL WHERE id = ?",
                arguments: [id]
            )
        }

        let results = try await repository.search(
            "",
            filter: CardFilter(dateRange: .today),
            now: Self.now,
            calendar: Self.utc
        )

        #expect(results.map(\.id) == [id])
    }

    @Test func `date ranges use calendar`() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        // 2026-03-08 is the day New York moves to daylight saving time
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 15)))
        func midnight(_ month: Int, _ day: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
        }

        let expected: [(DateRangeFilter, Range<Date>)] = try [
            (.today, midnight(3, 8) ..< midnight(3, 9)),
            (.yesterday, midnight(3, 7) ..< midnight(3, 8)),
            (.last7Days, midnight(3, 2) ..< midnight(3, 9)),
            (.last30Days, midnight(2, 7) ..< midnight(3, 9)),
            (.custom(from: now, through: now - 86400 * 2), midnight(3, 6) ..< midnight(3, 9))
        ]
        for (filter, range) in expected {
            #expect(filter.interval(now: now, calendar: calendar) == range, "\(filter)")
        }
        let today = DateRangeFilter.today.interval(now: now, calendar: calendar)
        #expect(today.upperBound.timeIntervalSince(today.lowerBound) == 23 * 3600)

        var tokyo = calendar
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(DateRangeFilter.today.interval(now: now, calendar: tokyo).lowerBound == now - 4 * 3600)
    }

    @discardableResult
    private func record(_ text: String, kind: CardKind, app: SourceApp, at date: Date) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: kind,
                representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))],
                contentHash: Data(text.utf8),
                previewText: text,
                metadata: nil,
                sourceApp: app
            ),
            at: date
        )
    }

    private static func daysAgo(_ days: Double) -> Date {
        now - days * 86400
    }

    private static let now = Date(timeIntervalSince1970: 1_794_916_800)
    private static let editor = SourceApp(bundleID: "com.example.editor", name: "Editor")
    private static let browser = SourceApp(bundleID: "com.example.browser", name: "Browser")
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }
}
