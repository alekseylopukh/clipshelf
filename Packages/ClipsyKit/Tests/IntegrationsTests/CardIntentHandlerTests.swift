import Foundation
import Store
import Testing
@testable import Integrations

struct CardIntentHandlerTests {
    let repository: CardRepository
    let handler: CardIntentHandler

    init() throws {
        repository = try CardRepository(database: AppDatabase.temporary())
        handler = CardIntentHandler(repository: repository)
    }

    @Test func `create card adds text to history`() async throws {
        let card = try await handler.createCard(text: "first note", in: .history)

        #expect(card.kind == .text)
        #expect(card.preview == "first note")
        #expect(try await repository.cards(in: .history).map(\.id) == [card.id])
        #expect(try await handler.text(of: card) == "first note")
    }

    @Test func `create card classifies like a copy`() async throws {
        let card = try await handler.createCard(text: "https://example.com", in: .history)

        #expect(card.kind == .link)
    }

    @Test func `create card goes to the front of a board only`() async throws {
        let board = try await repository.createBoard(named: "Work", color: "blue")
        let older = try await handler.createCard(text: "older", in: .board(id: board))

        let card = try await handler.createCard(text: "newer", in: .board(id: board))

        #expect(card.boardID == board)
        #expect(try await repository.cards(in: .board(id: board)).map(\.id) == [card.id, older.id])
        #expect(try await repository.cards(in: .history).isEmpty)
    }

    @Test func `create card refuses empty text`() async throws {
        await #expect(throws: CardIntentError.emptyText) {
            try await handler.createCard(text: "", in: .history)
        }
        #expect(try await repository.cards(in: .history).isEmpty)
    }

    @Test func `create card refuses existing content`() async throws {
        _ = try await handler.createCard(text: "same", in: .history)

        await #expect(throws: CardIntentError.duplicateContent) {
            try await handler.createCard(text: "same", in: .history)
        }
        #expect(try await repository.cards(in: .history).count == 1)
    }

    @Test func `create board takes the first unused color`() async throws {
        _ = try await repository.createBoard(named: "Red", color: "red")

        let board = try await handler.createBoard(named: "  Ideas ")

        #expect(board.name == "Ideas")
        #expect(board.color == "orange")
        #expect(try await repository.boards().map(\.id).last == board.id)
    }

    @Test func `card at position counts from the newest history card`() async throws {
        let oldest = try await record("one", hash: 1, at: 10)
        let middle = try await record("two", hash: 2, at: 20)
        let newest = try await record("three", hash: 3, at: 30)

        #expect(try await handler.card(at: 1, in: .history).id == newest)
        #expect(try await handler.card(at: 2, in: .history).id == middle)
        #expect(try await handler.card(at: 3, in: .history).id == oldest)
    }

    @Test func `card at position follows board order`() async throws {
        let board = try await repository.createBoard(named: "Work", color: "blue")
        let first = try await record("one", hash: 1, at: 10)
        let second = try await record("two", hash: 2, at: 20)
        try await repository.addCards([first, second], toBoard: board)

        #expect(try await handler.card(at: 1, in: .board(id: board)).id == first)
        #expect(try await handler.card(at: 2, in: .board(id: board)).id == second)
    }

    @Test(arguments: [0, -1, 2])
    func `card at missing position throws`(position: Int) async throws {
        _ = try await record("one", hash: 1, at: 10)

        await #expect(throws: CardIntentError.noCard(at: position)) {
            try await handler.card(at: position, in: .history)
        }
    }

    @Test func `latest card of kind is the newest in history`() async throws {
        _ = try await record("old link", hash: 1, kind: .link, at: 10)
        let newestLink = try await record("new link", hash: 2, kind: .link, at: 20)
        _ = try await record("text", hash: 3, at: 30)
        let boardOnly = try await handler.createCard(text: "https://example.com", in: .board(
            id: repository.createBoard(named: "Work", color: "blue")
        ))

        let card = try await handler.latestCard(of: .link)

        #expect(card.id == newestLink)
        #expect(card.id != boardOnly.id)
    }

    @Test func `latest card of missing kind throws`() async throws {
        _ = try await record("text", hash: 1, at: 10)

        await #expect(throws: CardIntentError.noCardOfKind) {
            try await handler.latestCard(of: .image)
        }
    }

    @Test func `text falls back to the preview`() async throws {
        let id = try await repository.record(NewCard(
            kind: .image,
            representations: [Representation(itemIndex: 0, uti: "public.png", data: Data([1, 2, 3]))],
            contentHash: Data([9]),
            previewText: "Image",
            metadata: nil,
            sourceApp: SourceApp(bundleID: "com.example.photos", name: "Photos")
        ))
        let card = try #require(try await repository.cards(withIDs: [id]).first)

        #expect(try await handler.text(of: card) == "Image")
    }

    private func record(_ text: String, hash: UInt8, kind: CardKind = .text, at time: Double) async throws -> Int64 {
        try await repository.record(
            NewCard(
                kind: kind,
                representations: [
                    Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))
                ],
                contentHash: Data([hash]),
                previewText: text,
                metadata: nil,
                sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
            ),
            at: Date(timeIntervalSince1970: time)
        )
    }
}
