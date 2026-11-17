import Foundation
import GRDB
import Testing
@testable import Store

struct TextCardEditingTests {
    let database: AppDatabase
    let repository: CardRepository

    init() throws {
        database = try AppDatabase.temporary()
        repository = CardRepository(database: database)
    }

    @Test func `edit keeps position and board`() async throws {
        let board = try await repository.createBoard(named: "Work", color: "blue")
        let older = try await repository.record(Self.card("one", hash: 1), at: Date(timeIntervalSince1970: 10))
        let edited = try await repository.record(Self.card("two", hash: 2), at: Date(timeIntervalSince1970: 20))
        let newer = try await repository.record(Self.card("three", hash: 3), at: Date(timeIntervalSince1970: 30))
        try await repository.addCards([edited, older], toBoard: board)
        try await repository.rename(card: edited, to: "Note")

        try await repository.replaceContent(of: edited, with: Self.card("two, edited", hash: 4))

        #expect(try await repository.cards(in: .history).map(\.id) == [newer, edited, older])
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [edited, older])
        let card = try #require(try await repository.cards(in: .history).first { $0.id == edited })
        #expect(card.preview == "two, edited")
        #expect(card.title == "Note")
        #expect(card.sourceApp?.bundleID == "com.example.notes")
        #expect(card.lastCopiedAt == Date(timeIntervalSince1970: 20))
    }

    @Test func `edit recomputes hash`() async throws {
        let id = try await repository.record(Self.card("draft", hash: 1))
        let large = String(repeating: "final ", count: 1000)

        try await repository.replaceContent(of: id, with: Self.card(large, hash: 2))

        #expect(try await contentHash(of: id) == Data([2]))
        #expect(try await repository.representations(of: id).map(\.data) == [Data(large.utf8)])
        #expect(try await repository.search("final").map(\.card.id) == [id])
        #expect(try await repository.search("draft").isEmpty)
        #expect(try await repository.record(Self.card("draft", hash: 1)) != id)
    }

    @Test func `edit to existing hash is refused`() async throws {
        let existing = try await repository.record(Self.card("one", hash: 1))
        let edited = try await repository.record(Self.card("two", hash: 2))

        await #expect(throws: CardEditError.duplicateContent) {
            try await repository.replaceContent(of: edited, with: Self.card("one", hash: 1))
        }

        #expect(try await contentHash(of: edited) == Data([2]))
        #expect(try await contentHash(of: existing) == Data([1]))
        #expect(try await repository.representations(of: edited).map(\.data) == [Data("two".utf8)])
    }

    @Test func `edit without changes saves`() async throws {
        let id = try await repository.record(Self.card("one", hash: 1))

        try await repository.replaceContent(of: id, with: Self.card("one", hash: 1))

        #expect(try await contentHash(of: id) == Data([1]))
    }

    @Test func `edit of a missing card throws`() async throws {
        await #expect(throws: RecordError.self) {
            try await repository.replaceContent(of: 42, with: Self.card("one", hash: 1))
        }
    }

    @Test func `new card goes to current board`() async throws {
        let board = try await repository.createBoard(named: "Work", color: "blue")
        let pinned = try await repository.record(Self.card("one", hash: 1))
        try await repository.addCards([pinned], toBoard: board)

        let id = try await repository.add(Self.card("new", hash: 2), to: .board(id: board))

        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [id, pinned])
        #expect(try await repository.cards(in: .history).map(\.id) == [pinned])
        #expect(try await repository.search("new").map(\.card.id) == [id])
    }

    @Test func `new card goes to top of history`() async throws {
        let older = try await repository.record(Self.card("one", hash: 1), at: Date(timeIntervalSince1970: 10))

        let id = try await repository.add(Self.card("new", hash: 2), to: .history, at: Date(timeIntervalSince1970: 20))

        #expect(try await repository.cards(in: .history).map(\.id) == [id, older])
    }

    @Test func `new card with existing content is refused`() async throws {
        try await repository.record(Self.card("one", hash: 1))

        await #expect(throws: CardEditError.duplicateContent) {
            try await repository.add(Self.card("one", hash: 1), to: .history)
        }
    }

    private static func card(_ text: String, hash: UInt8) -> NewCard {
        NewCard(
            kind: .text,
            representations: [Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))],
            contentHash: Data([hash]),
            previewText: String(text.prefix(1000)),
            metadata: nil,
            sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes"),
            searchBody: text.count > 1000 ? text : nil
        )
    }

    private func contentHash(of id: Int64) async throws -> Data? {
        try await database.pool.read { connection in
            try Data.fetchOne(connection, sql: "SELECT content_hash FROM card WHERE id = ?", arguments: [id])
        }
    }
}
