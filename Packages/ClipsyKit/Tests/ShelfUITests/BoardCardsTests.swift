import Foundation
import Store
import Testing
@testable import ShelfUI

@MainActor
final class BoardCardsTests {
    private let suiteName = "BoardCardsTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let repository: CardRepository
    private let model: ShelfModel
    private let editor: BoardEditor

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = try CardRepository(database: AppDatabase.temporary())
        self.repository = repository
        model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
        editor = BoardEditor(
            model: model,
            create: { try await repository.createBoard(named: $0, color: $1) },
            rename: { try await repository.renameBoard($0, to: $1) },
            recolor: { try await repository.recolorBoard($0, to: $1) },
            move: { try await repository.moveBoard($0, after: $1) },
            delete: { try await repository.deleteBoard($0) },
            addCards: { try await repository.addCards($0, toBoard: $1) },
            moveCards: { try await repository.moveCards($0, after: $1) }
        )
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeCards(_ count: Int) async throws -> [Int64] {
        var ids: [Int64] = []
        for index in 0 ..< count {
            let text = "Card \(index)"
            try await ids.append(repository.record(
                NewCard(
                    kind: .text,
                    representations: [
                        Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))
                    ],
                    contentHash: Data([UInt8(index)]),
                    previewText: text,
                    metadata: nil,
                    sourceApp: SourceApp(bundleID: "com.example.notes", name: "Notes")
                ),
                at: Date(timeIntervalSince1970: TimeInterval(index))
            ))
        }
        return ids
    }

    private func makeBoard(_ name: String = "Board") async throws -> Int64 {
        let id = try await repository.createBoard(named: name, color: "blue")
        try await model.receiveBoards(repository.boards())
        return id
    }

    private func show(_ list: CardList) async throws {
        model.showTab(list)
        try await model.receive(repository.cards(in: list))
    }

    private func boardCards(_ boardID: Int64) async throws -> [Int64] {
        try await repository.cards(in: .board(id: boardID)).map(\.id)
    }

    @Test func `add selection to board`() async throws {
        let cards = try await makeCards(3)
        let board = try await makeBoard()
        try await show(.history)
        model.select(cards[2])
        model.extendSelection(to: cards[0])

        await editor.add(model.selectedCards.map(\.id), to: board)

        #expect(try await boardCards(board) == [cards[2], cards[1], cards[0]])
        #expect(try await repository.cards(in: .history).count == 3)
    }

    @Test func `drop on capsule adds`() async throws {
        let cards = try await makeCards(3)
        let board = try await makeBoard()
        try await show(.history)
        model.select(cards[0])

        await editor.drop([.card(CardReference(cardID: cards[2]))], onBoard: board)
        #expect(try await boardCards(board) == [cards[2]])

        model.toggleSelection(of: cards[1])
        await editor.drop([.card(CardReference(cardID: cards[1]))], onBoard: board)
        #expect(try await boardCards(board) == [cards[1], cards[0], cards[2]])
    }

    @Test func `drop on the card's own board leaves it in place`() async throws {
        let cards = try await makeCards(2)
        let board = try await makeBoard()
        try await repository.addCards(cards, toBoard: board)
        try await show(.board(id: board))

        await editor.drop([.card(CardReference(cardID: cards[1]))], onBoard: board)

        #expect(try await boardCards(board) == cards)
    }

    @Test func `drop of a capsule on a capsule reorders the boards`() async throws {
        let first = try await makeBoard("First")
        let second = try await makeBoard("Second")

        await editor.drop([.board(BoardReference(boardID: second))], onBoard: first)

        #expect(try await repository.boards().map(\.id) == [second, first])
    }

    @Test func `boards offered for adding skip the one holding every card`() async throws {
        let cards = try await makeCards(2)
        let first = try await makeBoard("First")
        let second = try await makeBoard("Second")
        try await repository.addCards([cards[0]], toBoard: first)
        try await show(.history)

        #expect(editor.boards(forAdding: [model.cards[1]]).map(\.id) == [second])
        #expect(editor.boards(forAdding: model.cards).map(\.id) == [first, second])
    }

    @Test func `new board from the menu takes the cards and keeps the tab`() async throws {
        let cards = try await makeCards(2)
        try await show(.history)

        editor.beginNew(adding: cards)
        editor.name = "Trip"
        await editor.save()

        let board = try #require(try await repository.boards().first)
        #expect(board.name == "Trip")
        #expect(try await boardCards(board.id) == cards)
        #expect(model.tab == .history)
    }

    @Test(arguments: [
        (0, 2, [1, 2, 0, 3]),
        (3, 1, [0, 3, 1, 2]),
        (2, 0, [2, 0, 1, 3]),
        (1, 1, [0, 1, 2, 3])
    ])
    func `drop on a card reorders the board`(dragged: Int, target: Int, order: [Int]) async throws {
        let cards = try await makeCards(4)
        let board = try await makeBoard()
        try await repository.addCards(cards, toBoard: board)
        try await show(.board(id: board))

        await editor.reorder([cards[dragged]], onto: cards[target])

        #expect(try await boardCards(board) == order.map { cards[$0] })
    }

    @Test(arguments: [
        (ShelfModel.Direction.previous, [1, 3], [1, 3, 0, 2]),
        (.next, [0, 2], [1, 3, 0, 2]),
        (.previous, [0], [0, 1, 2, 3]),
        (.next, [2], [0, 1, 3, 2])
    ])
    func `keyboard moves the selection`(direction: ShelfModel.Direction, selected: [Int], order: [Int]) async throws {
        let cards = try await makeCards(4)
        let board = try await makeBoard()
        try await repository.addCards(cards, toBoard: board)
        try await show(.board(id: board))
        model.select(cards[selected[0]])
        for index in selected.dropFirst() {
            model.toggleSelection(of: cards[index])
        }

        await editor.moveSelection(direction)

        #expect(try await boardCards(board) == order.map { cards[$0] })
    }

    @Test func `history cannot be reordered`() async throws {
        let cards = try await makeCards(2)
        try await show(.history)
        model.select(cards[0])

        await editor.reorder([cards[0]], onto: cards[1])
        await editor.moveSelection(.next)

        #expect(try await repository.cards(in: .history).map(\.id) == [cards[1], cards[0]])
    }

    @Test func `search results on a board tab cannot be reordered`() async throws {
        let cards = try await makeCards(5)
        let board = try await makeBoard()
        try await repository.addCards(Array(cards[0 ..< 4]), toBoard: board)
        try await show(.board(id: board))
        let summaries = try await repository.cards(in: .board(id: board)) + repository.cards(in: .history)
        let results = [cards[4], cards[3], cards[1], cards[0]].compactMap { id in
            summaries.first { $0.id == id }.map { SearchResult(card: $0, titleMatches: [], previewMatches: []) }
        }
        model.query = "card"
        model.receiveResults(results)
        model.select(cards[3])

        await editor.reorder([cards[3]], onto: cards[1])
        await editor.moveSelection(.previous)
        await editor.moveSelection(.next)

        #expect(model.tab == .board(id: board))
        #expect(try await boardCards(board) == Array(cards[0 ..< 4]))
    }
}
