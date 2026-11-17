import Foundation
import GRDB
import Testing
@testable import Store

struct BoardTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test(arguments: ["", "  \n"])
    func `empty name becomes untitled`(name: String) async throws {
        let id = try await repository.createBoard(named: name, color: "blue")
        try await repository.renameBoard(id, to: "Work")
        #expect(try await repository.boards().map(\.name) == ["Work"])

        try await repository.renameBoard(id, to: name)

        #expect(try await repository.boards().map(\.name) == ["Untitled"])
    }

    @Test func `create appends and keeps color and date`() async throws {
        let first = try await repository.createBoard(named: "One", color: "red", at: Date(timeIntervalSince1970: 10))
        let second = try await repository.createBoard(named: "Two", color: "green")

        try await repository.recolorBoard(first, to: "purple")

        let boards = try await repository.boards()
        #expect(boards.map(\.id) == [first, second])
        #expect(boards.first?.color == "purple")
        #expect(boards.first?.createdAt == Date(timeIntervalSince1970: 10))
    }

    @Test(.timeLimit(.minutes(1)))
    func `board observation follows changes`() async throws {
        var updates = repository.observeBoards().makeAsyncIterator()
        #expect(try #require(try await updates.next()).isEmpty)

        let id = try await repository.createBoard(named: "Work", color: "blue")
        #expect(try #require(try await updates.next()).map(\.id) == [id])

        try await repository.deleteBoard(id)
        #expect(try #require(try await updates.next()).isEmpty)
    }

    @Test func `boards reorder`() async throws {
        let one = try await repository.createBoard(named: "One", color: "red")
        let two = try await repository.createBoard(named: "Two", color: "red")
        let three = try await repository.createBoard(named: "Three", color: "red")

        try await repository.moveBoard(three, after: nil)
        #expect(try await repository.boards().map(\.id) == [three, one, two])

        try await repository.moveBoard(three, after: one)
        #expect(try await repository.boards().map(\.id) == [one, three, two])

        try await repository.moveBoard(one, after: two)
        #expect(try await repository.boards().map(\.id) == [three, two, one])
    }

    @Test func `added cards go to the front in order`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let alpha = try await record("A", hash: 1)
        let bravo = try await record("B", hash: 2)
        let charlie = try await record("C", hash: 3)

        try await repository.addCards([alpha], toBoard: board)
        try await repository.addCards([bravo, charlie], toBoard: board)

        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [bravo, charlie, alpha])
        #expect(try await repository.cards(in: .history).count == 3)
    }

    @Test func `add to second board moves`() async throws {
        let first = try await repository.createBoard(named: "First", color: "blue")
        let second = try await repository.createBoard(named: "Second", color: "red")
        let card = try await record("A", hash: 1)
        try await repository.addCards([card], toBoard: first)

        try await repository.addCards([card], toBoard: second)

        #expect(try await repository.cards(in: .board(id: first)).isEmpty)
        #expect(try await repository.cards(in: .board(id: second)).map(\.id) == [card])
    }

    @Test func `remove from board deletes card outside history`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let inHistory = try await record("Kept", hash: 1)
        let boardOnly = try await record("Gone", hash: 2)
        try await repository.addCards([inHistory, boardOnly], toBoard: board)
        try await leaveHistory(boardOnly)

        try await repository.removeCardsFromBoard([inHistory, boardOnly])

        #expect(try await repository.cards(in: .board(id: board)).isEmpty)
        #expect(try await repository.cards(in: .history).map(\.id) == [inHistory])
        #expect(try await cardCount() == 1)
        #expect(try await searchRowIDs() == [inHistory])
    }

    @Test func `delete board keeps history cards`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let card = try await record("A", hash: 1)
        try await repository.addCards([card], toBoard: board)

        try await repository.deleteBoard(board)

        #expect(try await repository.boards().isEmpty)
        let history = try await repository.cards(in: .history)
        #expect(history.map(\.id) == [card])
        #expect(history.first?.boardID == nil)
    }

    @Test func `delete board deletes board only cards`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let other = try await repository.createBoard(named: "Other", color: "red")
        let boardOnly = try await record("A", hash: 1)
        let elsewhere = try await record("B", hash: 2)
        try await repository.addCards([boardOnly], toBoard: board)
        try await repository.addCards([elsewhere], toBoard: other)
        try await leaveHistory(boardOnly)
        try await leaveHistory(elsewhere)

        try await repository.deleteBoard(board)

        #expect(try await cardCount() == 1)
        #expect(try await searchRowIDs() == [elsewhere])
        #expect(try await repository.cards(in: .board(id: other)).map(\.id) == [elsewhere])
    }

    @Test func `reorder between neighbors`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let alpha = try await record("A", hash: 1)
        let bravo = try await record("B", hash: 2)
        let charlie = try await record("C", hash: 3)
        try await repository.addCards([alpha, bravo, charlie], toBoard: board)

        try await repository.moveCard(charlie, after: alpha)
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [alpha, charlie, bravo])
        let positions = try await boardPositions(board)
        #expect(positions[charlie] == ((positions[alpha] ?? 0) + (positions[bravo] ?? 0)) / 2)

        try await repository.moveCard(alpha, after: bravo)
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [charlie, bravo, alpha])

        try await repository.moveCard(alpha, after: nil)
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [alpha, charlie, bravo])
    }

    @Test func `reorder renumbers when neighbors are too close`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let alpha = try await record("A", hash: 1)
        let bravo = try await record("B", hash: 2)
        let charlie = try await record("C", hash: 3)
        try await repository.addCards([alpha, bravo, charlie], toBoard: board)

        for _ in 0 ..< 80 {
            try await repository.moveCard(charlie, after: alpha)
            try await repository.moveCard(bravo, after: alpha)
        }

        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [alpha, bravo, charlie])
        #expect(try await Set(boardPositions(board).values).count == 3)
    }

    @Test func `moving a card off a board throws`() async throws {
        let card = try await record("A", hash: 1)

        await #expect(throws: RecordError.self) {
            try await repository.moveCard(card, after: nil)
        }
    }

    private func record(_ text: String, hash: UInt8) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))],
                contentHash: Data([hash]),
                previewText: text,
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            ),
            at: Date(timeIntervalSince1970: TimeInterval(hash))
        )
    }

    private func leaveHistory(_ id: Int64) async throws {
        try await database.pool.write { connection in
            try connection.execute(sql: "UPDATE card SET last_copied_at = NULL WHERE id = ?", arguments: [id])
        }
    }

    private func cardCount() async throws -> Int {
        try await database.pool.read { connection in
            try Int.fetchOne(connection, sql: "SELECT COUNT(*) FROM card") ?? 0
        }
    }

    private func searchRowIDs() async throws -> [Int64] {
        try await database.pool.read { connection in
            try Int64.fetchAll(connection, sql: "SELECT rowid FROM card_search ORDER BY rowid")
        }
    }

    private func boardPositions(_ board: Int64) async throws -> [Int64: Double] {
        try await database.pool.read { connection in
            try Dictionary(uniqueKeysWithValues: Row.fetchAll(
                connection,
                sql: "SELECT id, board_position FROM card WHERE board_id = ?",
                arguments: [board]
            ).map { ($0[0], $0[1]) })
        }
    }
}
