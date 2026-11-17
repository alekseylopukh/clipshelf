import Foundation
import Store
import SwiftUI
import Synchronization
import Testing
@testable import ShelfUI

@MainActor
final class ShelfModelSearchTests {
    private let suiteName = "ShelfModelSearchTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeModel(cards ids: [Int64] = []) -> ShelfModel {
        makeSearchModel(cards: ids) { _, _ in AsyncThrowingStream { $0.finish() } }
    }

    private nonisolated static func results(_ ids: [Int64], boardID: Int64? = nil) -> [SearchResult] {
        cards(ids).map { card in
            var card = card
            card.boardID = boardID
            return SearchResult(card: card, titleMatches: [], previewMatches: [])
        }
    }

    private func makeSearchModel(
        cards ids: [Int64] = [],
        searchDelay: Duration = .zero,
        observeSearch: @escaping ShelfModel.SearchObservation
    ) -> ShelfModel {
        let model = ShelfModel(
            defaults: defaults,
            observe: { _ in AsyncThrowingStream { $0.finish() } },
            observeBoards: { AsyncThrowingStream { $0.finish() } },
            observeSearch: observeSearch,
            searchDelay: searchDelay
        )
        model.receive(Self.cards(ids))
        return model
    }

    private nonisolated static func cards(_ ids: [Int64]) -> [CardSummary] {
        ids.map { CardSummary(id: $0, kind: .text, createdAt: Date(timeIntervalSince1970: TimeInterval($0))) }
    }

    private static func boards(_ ids: [Int64]) -> [Board] {
        ids.map { Board(id: $0, name: "Board \($0)", color: "blue", createdAt: Date(timeIntervalSince1970: 0)) }
    }

    @Test func `typing starts search`() {
        let model = makeModel(cards: [3, 2, 1])

        #expect(model.typeToSearch("i"))
        #expect(model.query == "i")
        #expect(model.isSearchFieldFocused)
        model.searchFieldFocusDidChange(true)
        #expect(model.searchSelection == TextSelection(insertionPoint: model.query.endIndex))
        #expect(model.typeToSearch("n") == false)

        model.focusCards()
        model.searchFieldFocusDidChange(false)
        #expect(model.typeToSearch("n"))
        #expect(model.query == "in")
    }

    @Test(arguments: [" ", "\u{1B}", "\u{F702}", "\t"])
    func `non-typing keys do not start search`(characters: String) {
        let model = makeModel(cards: [1])

        #expect(model.typeToSearch(characters) == false)
        #expect(model.query.isEmpty)
        #expect(model.isSearchFieldFocused == false)
    }

    @Test func `command F focuses search and selects the query`() {
        let model = makeModel()
        model.query = "inv"

        model.focusSearch()
        model.searchFieldFocusDidChange(true)

        #expect(model.isSearchFieldFocused)
        #expect(model.searchSelection == TextSelection(range: model.query.startIndex ..< model.query.endIndex))
    }

    @Test func `command F twice opens the filter browser`() {
        let model = makeModel()
        model.query = "inv"

        model.focusSearch()
        #expect(model.isFilterBrowserPresented == false)
        model.searchFieldFocusDidChange(true)
        model.focusSearch()

        #expect(model.isFilterBrowserPresented)
        model.searchFieldFocusDidChange(false)
        model.searchSelection = nil
        model.searchFieldFocusDidChange(true)
        #expect(model.searchSelection == nil)
    }

    @Test func `search results act on the list each card is in`() {
        let model = makeModel()
        let inBoth = CardSummary(id: 3, kind: .text, createdAt: .now, lastCopiedAt: .now, boardID: 1)
        let boardOnly = CardSummary(id: 2, kind: .text, createdAt: .now, boardID: 2)
        let historyOnly = CardSummary(id: 1, kind: .text, createdAt: .now, lastCopiedAt: .now)
        let results = [inBoth, boardOnly, historyOnly].map {
            SearchResult(card: $0, titleMatches: [], previewMatches: [])
        }
        model.query = "inv"
        model.receiveResults(results)

        #expect(model.idsByList([3, 2, 1]).mapValues(Set.init) == [.history: [3, 1], .board(id: 2): [2]])
        #expect(model.removalList(for: [2]) == .board(id: 2))
        #expect(model.removalList(for: [3, 2]) == .history)

        model.showTab(.board(id: 1))
        model.query = "inv"
        model.receiveResults(results)

        #expect(model.list(of: inBoth) == .board(id: 1))
        #expect(model.list(of: historyOnly) == .history)
        #expect(model.idsByList([3, 2, 1]).mapValues(Set.init) == [
            .board(id: 1): [3],
            .board(id: 2): [2],
            .history: [1]
        ])
    }

    @Test func `results keep one selected`() {
        let model = makeSearchModel(cards: [9, 8]) { _, _ in AsyncThrowingStream { $0.finish() } }
        model.didOpen()
        model.query = "in"

        model.receiveResults(Self.results([5, 4, 3]))
        #expect(model.cards.map(\.id) == [5, 4, 3])
        #expect(model.selection == [5])

        model.select(4)
        model.receiveResults(Self.results([6, 4, 3]))
        #expect(model.selection == [4])

        model.receiveResults(Self.results([6, 3]))
        #expect(model.selection == [6])

        model.query = "inv"
        model.receiveResults(Self.results([3]))
        #expect(model.selection == [3])

        model.receive(Self.cards([10, 9, 8]))
        #expect(model.cards.map(\.id) == [3])

        model.query = ""
        #expect(model.cards.map(\.id) == [10, 9, 8])
        #expect(model.selection == [10])
        #expect(model.searchResult(for: 3) == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `query debounce cancels stale`() async {
        let requested = Mutex<[String]>([])
        let (stale, staleContinuation) = AsyncThrowingStream.makeStream(of: [SearchResult].self)
        let model = makeSearchModel(searchDelay: .milliseconds(200)) { text, _ in
            requested.withLock { $0.append(text) }
            return text == "ab" ? stale : AsyncThrowingStream { continuation in
                continuation.yield(Self.results([2]))
                continuation.finish()
            }
        }

        model.query = "a"
        let debounced = Task { await model.observeSearch() }
        model.query = "ab"
        debounced.cancel()
        await debounced.value
        #expect(requested.withLock { $0 }.isEmpty)

        let superseded = Task { await model.observeSearch() }
        while requested.withLock({ $0 }).isEmpty {
            await Task.yield()
        }
        model.query = "abc"
        staleContinuation.yield(Self.results([1]))
        staleContinuation.finish()
        await superseded.value
        #expect(model.cards.isEmpty)

        await model.observeSearch()

        #expect(requested.withLock { $0 } == ["ab", "abc"])
        #expect(model.cards.map(\.id) == [2])
    }

    @Test func `board marker shows only while searching`() {
        let model = makeModel()
        model.receiveBoards(Self.boards([1]))
        let card = Self.results([4], boardID: 1)[0].card

        #expect(model.board(of: card) == nil)
        model.query = "in"
        #expect(model.board(of: card)?.id == 1)
    }

    @Test func `opening and switching tabs clear the search`() {
        let model = makeModel(cards: [2, 1])
        model.receiveBoards(Self.boards([1]))
        model.query = "in"
        model.didOpen()
        #expect(model.query.isEmpty)

        model.query = "in"
        model.showTab(.board(id: 1))
        #expect(model.query.isEmpty)
    }

    @Test func `show in list selects card in its tab`() {
        let model = makeModel(cards: [5, 4, 3, 2, 1])
        model.receiveBoards(Self.boards([7]))
        model.didOpen()
        let boardOnly = CardSummary(id: 20, kind: .text, createdAt: .now, boardID: 7)
        let historyCard = CardSummary(id: 3, kind: .text, createdAt: .now, lastCopiedAt: .now)
        let results = [boardOnly, historyCard].map { SearchResult(card: $0, titleMatches: [], previewMatches: []) }

        model.query = "in"
        model.receiveResults(results)
        model.select(3)
        model.showInList(3)

        #expect(model.query.isEmpty)
        #expect(model.tab == .history)
        #expect(model.cards.map(\.id) == [5, 4, 3, 2, 1])
        #expect(model.selection == [3])
        #expect(model.revealedID == 3)
        #expect(model.isSearchFieldFocused == false)

        model.query = "in"
        model.receiveResults(results)
        model.showInList(20)

        #expect(model.query.isEmpty)
        #expect(model.tab == .board(id: 7))
        #expect(model.selection.isEmpty)
        model.receive(Self.cards([21, 20, 19]))
        #expect(model.selection == [20])
        #expect(model.revealedID == 20)

        model.move(.next)
        #expect(model.selection == [19])
        #expect(model.revealedID == nil)
    }

    @Test func `show in list with a token selects card in its tab`() {
        let model = makeModel(cards: [5, 4, 3, 2, 1])
        model.didOpen()
        let card = CardSummary(id: 3, kind: .text, createdAt: .now, lastCopiedAt: .now)

        model.query = "in"
        model.tokens = [.kind(.text)]
        model.receiveResults([SearchResult(card: card, titleMatches: [], previewMatches: [])])
        model.showInList(3)

        #expect(model.query.isEmpty)
        #expect(model.tokens.isEmpty)
        #expect(model.tab == .history)
        #expect(model.selection == [3])
        #expect(model.revealedID == 3)
    }

    @Test func `show in list falls back to the first card when the card is gone`() {
        let model = makeModel(cards: [2, 1])
        model.receiveBoards(Self.boards([7]))
        model.didOpen()
        let boardOnly = CardSummary(id: 20, kind: .text, createdAt: .now, boardID: 7)
        model.query = "in"
        model.receiveResults([SearchResult(card: boardOnly, titleMatches: [], previewMatches: [])])

        model.showInList(20)
        model.receive(Self.cards([9, 8]))

        #expect(model.selection == [9])
        #expect(model.revealedID == nil)
    }

    @Test func `show in list needs a search`() {
        let model = makeModel(cards: [2, 1])
        model.didOpen()

        model.showInList(1)

        #expect(model.selection == [2])
        #expect(model.revealedID == nil)
    }
}
