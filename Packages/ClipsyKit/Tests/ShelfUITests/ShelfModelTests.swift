import AppKit
import Carbon.HIToolbox
import Foundation
import KeyboardShortcuts
import Store
import Synchronization
import Testing
@testable import ShelfUI

@MainActor
final class ShelfModelTests {
    private let suiteName = "ShelfModelTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(
        cards ids: [Int64] = [],
        observe: @escaping ShelfModel.CardObservation = { _ in AsyncThrowingStream { $0.finish() } }
    ) -> ShelfModel {
        let model = ShelfModel(
            defaults: defaults,
            observe: observe,
            observeBoards: { AsyncThrowingStream { $0.finish() } }
        )
        if !ids.isEmpty {
            model.receive(Self.cards(ids))
        }
        return model
    }

    private static func boards(_ ids: [Int64]) -> [Board] {
        ids.map { Board(id: $0, name: "Board \($0)", color: "blue", createdAt: Date(timeIntervalSince1970: 0)) }
    }

    private static func cards(_ ids: [Int64]) -> [CardSummary] {
        ids.map { CardSummary(id: $0, kind: .text, createdAt: Date(timeIntervalSince1970: TimeInterval($0))) }
    }

    @Test func `arrows move selection`() {
        let model = makeModel(cards: [5, 4, 3])
        model.didOpen()

        model.move(.next)
        #expect(model.selection == [4])
        model.move(.next)
        model.move(.next)
        #expect(model.selection == [3])
        model.move(.previous)
        #expect(model.selection == [4])
        model.selectFirst()
        #expect(model.selection == [5])
        model.move(.previous)
        #expect(model.selection == [5])
        model.selectLast()
        #expect(model.selection == [3])
    }

    @Test func `shift arrow extends`() {
        let model = makeModel(cards: [5, 4, 3, 2])
        model.select(4)

        model.move(.next, extending: true)
        model.move(.next, extending: true)
        #expect(model.selection == [4, 3, 2])

        model.move(.previous, extending: true)
        #expect(model.selection == [4, 3])

        model.move(.previous, extending: true)
        model.move(.previous, extending: true)
        #expect(model.selection == [5, 4])
    }

    @Test func `shift click extends from anchor`() {
        let model = makeModel(cards: [5, 4, 3, 2])
        model.select(4)

        model.extendSelection(to: 2)

        #expect(model.selection == [4, 3, 2])
    }

    @Test func `command click toggles`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(5)

        model.toggleSelection(of: 3)
        #expect(model.selection == [5, 3])

        model.toggleSelection(of: 5)
        #expect(model.selection == [3])
    }

    @Test func `select all selects current list`() {
        let model = makeModel(cards: [5, 4, 3])

        model.selectAll()

        #expect(model.selection == [5, 4, 3])
    }

    @Test func `selection survives insert at front`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(4)

        model.receive(Self.cards([6, 5, 4, 3]))
        #expect(model.selection == [4])

        model.move(.next)
        #expect(model.selection == [3])
    }

    @Test func `removed cards leave selection`() {
        let model = makeModel(cards: [5, 4, 3])
        model.selectAll()

        model.receive(Self.cards([5, 3]))

        #expect(model.selection == [5, 3])
    }

    @Test func `open selects newest`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(3)

        model.didOpen()

        #expect(model.selection == [5])
    }

    @Test func `open before cards arrive selects newest on load`() {
        let model = makeModel()

        model.didOpen()
        #expect(model.selection.isEmpty)
        model.receive(Self.cards([5, 4]))

        #expect(model.selection == [5])
    }

    @Test func `last tab is remembered`() {
        let model = makeModel(cards: [5, 4])

        model.showTab(.board(id: 7))

        #expect(model.cards.isEmpty)
        #expect(model.selection.isEmpty)
        #expect(makeModel().tab == .board(id: 7))
    }

    @Test func `observation feeds current tab`() async {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: [CardSummary].self)
        continuation.yield(Self.cards([2, 1]))
        continuation.yield(Self.cards([3, 2, 1]))
        continuation.finish()
        let requested = Mutex<[CardList]>([])
        let model = makeModel { list in
            requested.withLock { $0.append(list) }
            return stream
        }
        model.showTab(.board(id: 1))

        await model.observeCards()

        #expect(requested.withLock { $0 } == [.board(id: 1)])
        #expect(model.cards.map(\.id) == [3, 2, 1])
        #expect(model.selection == [2])
    }

    @Test func `observation failure is reported`() async {
        struct Failure: Error {}
        let model = makeModel { _ in AsyncThrowingStream { $0.finish(throwing: Failure()) } }

        await model.observeCards()

        #expect(model.observationError is Failure)
    }

    @Test func `neighbor after removal is next card, else previous`() {
        let model = makeModel(cards: [5, 4, 3, 2])

        #expect(model.neighbor(afterRemoving: [4, 3]) == 2)
        #expect(model.neighbor(afterRemoving: [3, 2]) == 4)
        #expect(model.neighbor(afterRemoving: [5, 4, 3, 2]) == nil)
        #expect(model.neighbor(afterRemoving: [9]) == nil)
    }

    @Test func `selected cards keep list order`() {
        let model = makeModel(cards: [5, 4, 3])
        model.select(3)
        model.toggleSelection(of: 5)

        #expect(model.selectedCards.map(\.id) == [5, 3])
    }

    @Test func `selection keys move, extend and select all`() {
        let model = makeModel(cards: [5, 4, 3])
        model.didOpen()

        #expect(model.handleSelectionKey(keyCode: kVK_RightArrow, character: nil, modifiers: []))
        #expect(model.selection == [4])
        #expect(model.handleSelectionKey(keyCode: kVK_RightArrow, character: nil, modifiers: .shift))
        #expect(model.selection == [4, 3])
        #expect(model.handleSelectionKey(keyCode: kVK_UpArrow, character: nil, modifiers: .command))
        #expect(model.selection == [5])
        #expect(model.handleSelectionKey(keyCode: kVK_ANSI_A, character: "a", modifiers: .command))
        #expect(model.selection == [5, 4, 3])
    }

    @Test func `other keys are left to the shelf`() {
        let model = makeModel(cards: [5, 4])
        model.didOpen()

        #expect(model.handleSelectionKey(keyCode: kVK_LeftArrow, character: nil, modifiers: .command) == false)
        #expect(model.handleSelectionKey(keyCode: kVK_ANSI_C, character: "c", modifiers: .command) == false)
        #expect(model.selection == [5])
    }

    @Test func `esc clears search first`() {
        let model = makeModel()
        model.query = "invoice"

        #expect(model.clearSearch())
        #expect(model.query.isEmpty)
        #expect(model.clearSearch() == false)
    }

    @Test func `tab shortcuts switch tabs`() {
        let model = makeModel()
        model.receiveBoards(Self.boards([1, 2]))
        let previous = KeyboardShortcuts.Shortcut(.leftArrow, modifiers: .command)
        let next = KeyboardShortcuts.Shortcut(.rightArrow, modifiers: .command)

        #expect(model.handleTabShortcut(next))
        #expect(model.tab == .board(id: 1))
        #expect(model.handleTabShortcut(next))
        #expect(model.handleTabShortcut(next))
        #expect(model.tab == .board(id: 2))
        #expect(model.handleTabShortcut(previous))
        #expect(model.handleTabShortcut(previous))
        #expect(model.handleTabShortcut(previous))
        #expect(model.tab == .history)
        #expect(model.handleTabShortcut(KeyboardShortcuts.Shortcut(.leftArrow)) == false)
    }

    @Test func `tab shortcuts are customizable`() throws {
        let custom = KeyboardShortcuts.Shortcut(.rightBracket, modifiers: [.command, .shift])
        try defaults.set(String(bytes: JSONEncoder().encode(custom), encoding: .utf8), forKey: TabShortcuts.nextKey)
        let model = makeModel()
        model.receiveBoards(Self.boards([1]))

        #expect(model.handleTabShortcut(KeyboardShortcuts.Shortcut(.rightArrow, modifiers: .command)) == false)
        #expect(model.handleTabShortcut(custom))
        #expect(model.tab == .board(id: 1))
    }

    @Test func `removed board falls back to history`() {
        defaults.set("board:2", forKey: "ShelfTab")
        let model = makeModel()
        model.receiveBoards(Self.boards([1, 2]))
        #expect(model.tab == .board(id: 2))

        model.receiveBoards(Self.boards([1]))

        #expect(model.tab == .history)
        #expect(makeModel().tab == .history)
    }

    @Test func `remembered board missing at launch falls back to history`() {
        defaults.set("board:3", forKey: "ShelfTab")
        let model = makeModel()

        model.receiveBoards(Self.boards([1, 2]))

        #expect(model.tab == .history)
    }

    @Test func `board not listed yet keeps its tab`() {
        let model = makeModel()
        model.receiveBoards(Self.boards([1]))

        model.showTab(.board(id: 2))
        model.receiveBoards(Self.boards([1]))
        #expect(model.tab == .board(id: 2))

        model.receiveBoards(Self.boards([1, 2]))
        model.receiveBoards(Self.boards([1]))
        #expect(model.tab == .history)
    }

    @Test func `empty states follow tab, search and pause`() {
        let model = makeModel()
        #expect(model.emptyState(isCapturePaused: false) == nil)

        model.receive([])
        #expect(model.emptyState(isCapturePaused: false) == .history)
        #expect(model.emptyState(isCapturePaused: true) == .paused)
        model.query = "invoice"
        #expect(model.emptyState(isCapturePaused: true) == nil)
        model.receiveResults([])
        #expect(model.emptyState(isCapturePaused: true) == .noResults)
        model.query = ""

        model.showTab(.board(id: 1))
        #expect(model.emptyState(isCapturePaused: false) == nil)
        model.receive([])
        #expect(model.emptyState(isCapturePaused: true) == .board)
        model.receive(Self.cards([1]))
        #expect(model.emptyState(isCapturePaused: false) == nil)
    }

    @Test func `first list loads, later lists are edits`() {
        let model = makeModel()

        model.receive(Self.cards([2, 1]))
        #expect(model.arrival == .load)
        model.receive(Self.cards([3, 2, 1]))
        #expect(model.arrival == .edit)
    }

    @Test(arguments: [
        (CardList.history, CardList.board(id: 1), false),
        (CardList.board(id: 1), CardList.history, true),
        (CardList.board(id: 1), CardList.board(id: 2), false),
        (CardList.board(id: 2), CardList.board(id: 1), true),
    ])
    func `new tab's cards arrive from its side`(from: CardList, to: CardList, fromLeading: Bool) {
        let model = makeModel()
        model.receiveBoards(Self.boards([1, 2]))
        model.showTab(from)
        model.receive(Self.cards([1]))

        model.showTab(to)
        model.receive(Self.cards([2]))
        #expect(model.arrival == .tab(fromLeading: fromLeading))

        model.receive(Self.cards([3, 2]))
        #expect(model.arrival == .edit)
    }

    @Test func `search results and clearing the search crossfade`() {
        let model = makeModel(cards: [3, 2, 1])

        model.query = "invoice"
        model.receiveResults(Self.results([2]))
        #expect(model.arrival == .search)
        model.receiveResults(Self.results([2, 1]))
        #expect(model.arrival == .edit)

        model.query = ""
        #expect(model.arrival == .search)
    }

    @Test func `switching tabs while searching arrives as a tab switch`() {
        let model = makeModel(cards: [3, 2, 1])
        model.receiveBoards(Self.boards([1]))
        model.query = "invoice"
        model.receiveResults(Self.results([2]))

        model.showTab(.board(id: 1))
        model.receive(Self.cards([5]))

        #expect(model.arrival == .tab(fromLeading: false))
    }

    @Test func `prewarm keeps order, skips duplicates and stops at twelve cards`() {
        let apps = (5 ... 13).map { "com.example.app\($0)" }
        let bundleIDs: [String?] = ["com.example.a", "com.example.b", "com.example.a", nil] + apps
        let model = makeModel()

        model.receive(bundleIDs.enumerated().map { index, bundleID in
            CardSummary(
                id: Int64(index + 1),
                kind: .text,
                sourceApp: bundleID.map { SourceApp(bundleID: $0, name: "App") },
                createdAt: Date(timeIntervalSince1970: 0)
            )
        })

        #expect(model.prewarmBundleIDs == ["com.example.a", "com.example.b"] + apps.dropLast())
    }

    private static func results(_ ids: [Int64]) -> [SearchResult] {
        cards(ids).map { SearchResult(card: $0, titleMatches: [], previewMatches: []) }
    }
}
