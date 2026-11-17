import Foundation
import GRDB
import Testing
@testable import Store

struct CardQueriesTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test func `history is newest first`() async throws {
        let old = try await record("Old", hash: 1, at: 100)
        let new = try await record("New", hash: 2, at: 300)
        let middle = try await record("Middle", hash: 3, at: 200)
        try await record("Old", hash: 1, at: 400)

        let history = try await repository.cards(in: .history)

        #expect(history.map(\.id) == [old, new, middle])
        let first = try #require(history.first)
        #expect(first.kind == .text)
        #expect(first.preview == "Old")
        #expect(first.sourceApp == Self.notes)
        #expect(first.createdAt == Date(timeIntervalSince1970: 100))
        #expect(first.lastCopiedAt == Date(timeIntervalSince1970: 400))
        #expect(first.boardID == nil)
    }

    @Test func `board is by position`() async throws {
        let last = try await record("A", hash: 1, at: 100)
        let first = try await record("B", hash: 2, at: 200)
        let second = try await record("C", hash: 3, at: 300)
        let other = try await record("Other", hash: 4, at: 400)
        try await database.pool.write { connection in
            try connection.execute(sql: """
            INSERT INTO board (id, name, color, position, created_at) VALUES (1, 'One', 'blue', 1, 0), (2, 'Two', 'red', 2, 0)
            """)
            for (id, board, position) in [(last, 1, 2.0), (first, 1, 0.5), (second, 1, 1.0), (other, 2, 0.0)] {
                try connection.execute(
                    sql: "UPDATE card SET board_id = ?, board_position = ? WHERE id = ?",
                    arguments: [board, position, id]
                )
            }
        }

        let board = try await repository.cards(in: .board(id: 1))

        #expect(board.map(\.id) == [first, second, last])
        #expect(board.allSatisfy { $0.boardID == 1 })
    }

    @Test func `history excludes board only cards`() async throws {
        let kept = try await record("Kept", hash: 1, at: 100)
        let boardOnly = try await record("Board only", hash: 2, at: 200)
        try await database.pool.write { connection in
            try connection
                .execute(sql: "INSERT INTO board (id, name, color, position, created_at) VALUES (1, 'B', 'blue', 1, 0)")
            try connection.execute(
                sql: "UPDATE card SET board_id = 1, board_position = 1, last_copied_at = NULL WHERE id = ?",
                arguments: [boardOnly]
            )
        }

        #expect(try await repository.cards(in: .history).map(\.id) == [kept])
        #expect(try await repository.cards(in: .board(id: 1)).map(\.id) == [boardOnly])
    }

    @Test(.timeLimit(.minutes(1)))
    func `observation emits on insert`() async throws {
        var updates = repository.observeCards(in: .history).makeAsyncIterator()
        #expect(try #require(try await updates.next()).isEmpty)

        let id = try await record("New", hash: 1, at: 100)

        let cards = try #require(try await updates.next())
        #expect(cards.map(\.id) == [id])
    }

    @Test func `cards with ids returns only those cards`() async throws {
        let first = try await record("First", hash: 1, at: 100)
        try await record("Other", hash: 2, at: 200)
        let third = try await record("Third", hash: 3, at: 300)

        let cards = try await repository.cards(withIDs: [third, first, 999])

        #expect(Set(cards.map(\.id)) == [first, third])
        #expect(try await repository.cards(withIDs: []).isEmpty)
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
                sourceApp: Self.notes
            ),
            at: Date(timeIntervalSince1970: time)
        )
    }

    private static let notes = SourceApp(bundleID: "com.example.notes", name: "Notes")
}
