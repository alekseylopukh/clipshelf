import Foundation
import GRDB
import Testing
@testable import Store

struct DeletionTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test func `delete in history keeps board cards`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let historyOnly = try await record(byte: 1, at: 10)
        let both = try await record(byte: 2, at: 20)
        try await repository.addCards([both], toBoard: board)

        _ = try await repository.delete(cards: [historyOnly, both], in: .history)

        #expect(try await repository.cards(in: .history).isEmpty)
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [both])
        #expect(try await searchRowIDs() == [both])
    }

    @Test func `delete on board keeps history`() async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let both = try await record(byte: 1, at: 10)
        let boardOnly = try await record(byte: 2, at: 20)
        try await repository.addCards([both, boardOnly], toBoard: board)
        try await leaveHistory(boardOnly)

        _ = try await repository.delete(cards: [both, boardOnly], in: .board(id: board))

        #expect(try await repository.cards(in: .board(id: board)).isEmpty)
        let history = try await repository.cards(in: .history)
        #expect(history.map(\.id) == [both])
        #expect(history.first?.boardID == nil)
        #expect(try await searchRowIDs() == [both])
    }

    @Test(arguments: [false, true])
    func `restore undoes delete`(onBoard: Bool) async throws {
        let board = try await repository.createBoard(named: "B", color: "blue")
        let large = Data(repeating: 7, count: PayloadStore.inlineLimit)
        let both = try await record(byte: 1, at: 10, data: large)
        let boardOnly = try await record(byte: 2, at: 20)
        let historyOnly = try await record(byte: 3, at: 30)
        try await repository.addCards([both, boardOnly], toBoard: board)
        try await leaveHistory(boardOnly)
        let list: CardList = onBoard ? .board(id: board) : .history
        let before = try await (repository.cards(in: .history), repository.cards(in: .board(id: board)))

        let deleted = try await repository.delete(cards: [both, boardOnly, historyOnly], in: list)
        let restored = try await repository.restore(deleted)

        #expect(Set(restored) == (onBoard ? [both, boardOnly] : [both, historyOnly]))
        let after = try await (repository.cards(in: .history), repository.cards(in: .board(id: board)))
        #expect(after.0 == before.0)
        #expect(after.1 == before.1)
        #expect(try await repository.representations(of: both).map(\.data) == [large])
        #expect(try await searchRowIDs() == [both, boardOnly, historyOnly])
    }

    @Test func `restore merges into a card copied again`() async throws {
        let card = try await record(byte: 1, at: 10)
        let deleted = try await repository.delete(cards: [card], in: .history)
        let copiedAgain = try await record(byte: 1, at: 300)

        let restored = try await repository.restore(deleted)

        #expect(restored == [copiedAgain])
        let history = try await repository.cards(in: .history)
        #expect(history.map(\.id) == [copiedAgain])
        #expect(history.first?.lastCopiedAt == Date(timeIntervalSince1970: 300))
    }

    @Test func `restore uses a new id when the old one was reused`() async throws {
        let card = try await record(byte: 1, at: 10)
        let deleted = try await repository.delete(cards: [card], in: .history)
        let newer = try await record(byte: 2, at: 20)
        #expect(newer == card)

        let restored = try await repository.restore(deleted)

        let history = try await repository.cards(in: .history)
        #expect(history.map(\.id) == [newer] + restored)
        #expect(history.map(\.preview) == ["Card 2", "Card 1"])
        #expect(try await searchRowIDs() == [newer] + restored)
    }

    @Test func `restore skips a card whose payload was collected`() async throws {
        let card = try await record(byte: 1, at: 10, data: Data(repeating: 7, count: PayloadStore.inlineLimit))
        let deleted = try await repository.delete(cards: [card], in: .history)
        try await repository.eraseHistory()

        #expect(try await repository.restore(deleted).isEmpty)
        #expect(try await repository.cards(in: .history).isEmpty)
    }

    @discardableResult
    private func record(byte: UInt8, at time: TimeInterval, data: Data? = nil) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: .text,
                representations: [
                    Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: data ?? Data([byte]))
                ],
                contentHash: Data([byte]),
                previewText: "Card \(byte)",
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            ),
            at: Date(timeIntervalSince1970: time)
        )
    }

    private func leaveHistory(_ id: Int64) async throws {
        try await database.pool.write { connection in
            try connection.execute(sql: "UPDATE card SET last_copied_at = NULL WHERE id = ?", arguments: [id])
        }
    }

    private func searchRowIDs() async throws -> [Int64] {
        try await database.pool.read { connection in
            try Int64.fetchAll(connection, sql: "SELECT rowid FROM card_search ORDER BY rowid")
        }
    }
}
