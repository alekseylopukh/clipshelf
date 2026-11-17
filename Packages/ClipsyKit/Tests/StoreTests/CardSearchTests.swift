import Foundation
import GRDB
import Testing
@testable import Store

struct CardSearchTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test func `prefix matches`() async throws {
        let hello = try await record("Hello world", hash: 1, at: 100)
        let help = try await record("Ask for help", hash: 2, at: 200)
        try await record("Shell script", hash: 3, at: 300)

        let results = try await repository.search("HEL")

        #expect(results.map(\.id) == [help, hello])
        let first = try #require(results.first)
        #expect(first.previewMatches.map { String(first.card.preview?[$0] ?? "") } == ["hel"])
        #expect(try await repository.search("ello").isEmpty)
        #expect(try await repository.search("hel wor").map(\.id) == [hello])
    }

    @Test func `diacritics are folded`() async throws {
        let id = try await record("Café crème", hash: 1, at: 100)

        for query in ["cafe creme", "CAFÉ", "crè"] {
            #expect(try await repository.search(query).map(\.id) == [id])
        }
        let result = try #require(try await repository.search("cafe").first)
        #expect(result.previewMatches.map { String(result.card.preview?[$0] ?? "") } == ["Café"])
    }

    @Test func `matches app name`() async throws {
        let id = try await record("Groceries", hash: 1, at: 100)

        let result = try #require(try await repository.search("edi").first)

        #expect(result.id == id)
        #expect(result.previewMatches.isEmpty)
    }

    @Test(arguments: [
        "\"",
        "hello\"",
        "hello*",
        "(hello",
        "hello OR zzz",
        "NOT hello",
        "-hello",
        "body:hello",
        "NEAR(hello)",
        "^hello",
        "hello AND"
    ])
    func `fts5 operators in input are literal`(query: String) async throws {
        let id = try await record("Hello world", hash: 1, at: 100)
        try await record("Not or and near body", hash: 2, at: 200)

        let ids = try await repository.search(query).map(\.id)

        let terms = SearchQuery(query).terms.map { $0.lowercased() }
        if terms == ["hello"] {
            #expect(ids == [id])
        } else {
            #expect(ids.contains(id) == false)
        }
    }

    @Test func `results include board only cards`() async throws {
        let history = try await record("Note one", hash: 1, at: 100)
        let boardOnly = try await record("Note two", hash: 2, at: 200)
        let both = try await record("Note three", hash: 3, at: 300)
        try await database.pool.write { connection in
            try connection
                .execute(sql: "INSERT INTO board (id, name, color, position, created_at) VALUES (1, 'B', 'blue', 1, 0)")
            try connection.execute(
                sql: "UPDATE card SET board_id = 1, board_position = 1, last_copied_at = NULL WHERE id = ?",
                arguments: [boardOnly]
            )
            try connection.execute(
                sql: "UPDATE card SET board_id = 1, board_position = 2 WHERE id = ?",
                arguments: [both]
            )
        }

        let results = try await repository.search("note")

        #expect(results.map(\.id) == [both, boardOnly, history])
        #expect(results.map(\.card.boardID) == [1, 1, nil])
    }

    @Test(.timeLimit(.minutes(1)))
    func `search observation emits on insert`() async throws {
        try await record("Hello world", hash: 1, at: 100)
        var updates = repository.observeSearch("hel").makeAsyncIterator()
        #expect(try #require(try await updates.next()).count == 1)

        let id = try await record("Help", hash: 2, at: 200)

        let results = try #require(try await updates.next())
        #expect(results.first?.id == id)
        #expect(results.count == 2)
    }

    @Test func `blank query returns nothing`() async throws {
        try await record("Hello", hash: 1, at: 100)

        #expect(try await repository.search(" \"*() ").isEmpty)
    }

    @discardableResult
    private func record(_ text: String, hash: UInt8, at time: TimeInterval) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))],
                contentHash: Data([hash]),
                previewText: text,
                metadata: nil,
                sourceApp: Self.editor
            ),
            at: Date(timeIntervalSince1970: time)
        )
    }

    private static let editor = SourceApp(bundleID: "com.example.editor", name: "Editor")
}
