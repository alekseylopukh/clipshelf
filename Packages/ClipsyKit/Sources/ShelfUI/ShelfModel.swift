import Foundation
import KeyboardShortcuts
import Observation
import os
import Store
import SwiftUI

@MainActor
@Observable
public final class ShelfModel {
    public typealias CardObservation = @Sendable (CardList) -> any AsyncSequence<[CardSummary], any Error> & Sendable
    public typealias BoardObservation = @Sendable () -> any AsyncSequence<[Board], any Error> & Sendable
    public typealias SearchObservation = @Sendable (String, CardFilter)
        -> any AsyncSequence<[SearchResult], any Error> & Sendable
    public typealias AppObservation = @Sendable () -> any AsyncSequence<[SourceApp], any Error> & Sendable

    public enum Direction: Sendable {
        case previous
        case next
    }

    public private(set) var tab: CardList
    public private(set) var cards: [CardSummary] = []
    public private(set) var boards: [Board] = []
    var query = "" {
        didSet {
            highlightedSuggestion = nil
            updateSuggestions()
            if !isResettingSearch, Self.searchText(of: oldValue) != searchText {
                searchTextDidChange()
            }
        }
    }

    var tokens: [SearchToken] = [] {
        didSet {
            if oldValue != tokens {
                updateSuggestions()
                if !isResettingSearch {
                    searchTextDidChange()
                }
            }
        }
    }

    var apps: [SourceApp] = []
    var suggestions: [SearchToken] = []
    var highlightedSuggestion: SearchToken?
    var isFilterBrowserPresented = false

    var searchSelection: TextSelection?
    var isSearchFieldFocused = false
    var requestedSearchSelection: TextSelection?
    private var listCards: [CardSummary] = []
    private var hasLoadedList = false
    private var hasLoadedBoards = false
    private var hasLoadedResults = false
    private var searchResults: [Int64: SearchResult] = [:]
    public private(set) var selection: Set<Int64> = []
    public private(set) var observationError: (any Error)?
    public private(set) var isQuickPasteModifierHeld = false
    private var visibleCardIDs: Set<Int64> = []
    private var quickPasteCardIDs: [Int64] = []

    private var anchorID: Int64?
    private(set) var cursorID: Int64?
    private(set) var revealedID: Int64?
    private var selectsFirstOnLoad = true
    private var pendingRevealID: Int64?
    @ObservationIgnored private var isResettingSearch = false

    @ObservationIgnored private let observe: CardObservation
    @ObservationIgnored private let observeBoardList: BoardObservation
    @ObservationIgnored private let observeSearchResults: SearchObservation
    @ObservationIgnored let observeAppList: AppObservation
    @ObservationIgnored private let searchDelay: Duration
    @ObservationIgnored private let defaults: UserDefaults

    private static let tabKey = "ShelfTab"
    static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    public init(
        defaults: UserDefaults = .standard,
        observe: @escaping CardObservation,
        observeBoards: @escaping BoardObservation,
        observeSearch: @escaping SearchObservation = { _, _ in AsyncThrowingStream { $0.finish() } },
        observeApps: @escaping AppObservation = { AsyncThrowingStream { $0.finish() } },
        searchDelay: Duration = .milliseconds(150)
    ) {
        self.defaults = defaults
        self.observe = observe
        observeBoardList = observeBoards
        observeSearchResults = observeSearch
        observeAppList = observeApps
        self.searchDelay = searchDelay
        tab = Self.decodeTab(defaults.string(forKey: Self.tabKey)) ?? .history
    }

    public func observeCards() async {
        let list = tab
        do {
            for try await cards in observe(list) {
                guard list == tab else { return }
                receive(cards)
            }
        } catch is CancellationError {
            return
        } catch {
            guard list == tab else { return }
            Self.logger.error("card observation failed: \(String(describing: type(of: error)), privacy: .public)")
            observationError = error
        }
    }

    public func observeBoards() async {
        do {
            for try await boards in observeBoardList() {
                receiveBoards(boards)
            }
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("board observation failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    var tabs: [CardList] {
        [.history] + boards.map { .board(id: $0.id) }
    }

    func emptyState(isCapturePaused: Bool) -> ShelfEmptyState? {
        guard isSearching ? hasLoadedResults : hasLoadedList, cards.isEmpty else { return nil }
        if isSearching {
            return .noResults
        }
        switch tab {
        case .history: return isCapturePaused ? .paused : .history
        case .board: return .board
        }
    }

    func clearSearch() -> Bool {
        guard !query.isEmpty || !tokens.isEmpty else { return false }
        resetSearch()
        return true
    }

    func showAdjacentTab(_ direction: Direction) {
        let tabs = tabs
        guard let index = tabs.firstIndex(of: tab) else { return }
        let target = index + (direction == .next ? 1 : -1)
        guard tabs.indices.contains(target) else { return }
        showTab(tabs[target])
    }

    func handleTabShortcut(_ shortcut: KeyboardShortcuts.Shortcut) -> Bool {
        guard let direction = TabShortcuts(defaults: defaults).direction(of: shortcut) else { return false }
        showAdjacentTab(direction)
        return true
    }

    public func didOpen() {
        isSearchFieldFocused = false
        pendingRevealID = nil
        resetSearch()
        clearSelection()
        selectsFirstOnLoad = true
        selectFirstIfPending()
    }

    public func showTab(_ list: CardList) {
        guard list != tab else { return }
        tab = list
        defaults.set(Self.encodeTab(list), forKey: Self.tabKey)
        listCards = []
        hasLoadedList = false
        pendingRevealID = nil
        resetSearch()
        cards = []
        observationError = nil
        clearSelection()
        selectsFirstOnLoad = true
        setVisibleCards([])
    }

    public func setVisibleCards(_ ids: [Int64]) {
        visibleCardIDs = Set(ids)
        updateQuickPasteCards()
    }

    public func setQuickPasteModifierHeld(_ isHeld: Bool) {
        isQuickPasteModifierHeld = isHeld
    }

    public func quickPasteNumber(for id: Int64) -> Int? {
        guard isQuickPasteModifierHeld, let index = quickPasteCardIDs.firstIndex(of: id) else { return nil }
        return index + 1
    }

    public func quickPasteCard(number: Int) -> Int64? {
        quickPasteCardIDs.indices.contains(number - 1) ? quickPasteCardIDs[number - 1] : nil
    }

    public func move(_ direction: Direction, extending: Bool = false) {
        guard !cards.isEmpty else { return }
        guard let cursorIndex = cursorID.flatMap(index(of:)) else {
            select(cards[0].id)
            return
        }
        let step = direction == .next ? 1 : -1
        let target = cards[min(max(cursorIndex + step, 0), cards.count - 1)].id
        if extending {
            extendSelection(to: target)
        } else {
            select(target)
        }
    }

    public func selectFirst() {
        guard let first = cards.first else { return }
        select(first.id)
    }

    public func selectLast() {
        guard let last = cards.last else { return }
        select(last.id)
    }

    public func select(_ id: Int64) {
        selection = [id]
        anchorID = id
        cursorID = id
        revealedID = nil
    }

    public func toggleSelection(of id: Int64) {
        if selection.remove(id) == nil {
            selection.insert(id)
        }
        anchorID = id
        cursorID = id
    }

    public func extendSelection(to id: Int64) {
        guard let target = index(of: id), let anchor = anchorID.flatMap(index(of:)) else {
            select(id)
            return
        }
        selection = Set(cards[min(anchor, target) ... max(anchor, target)].map(\.id))
        cursorID = id
    }

    public func selectAll() {
        selection = Set(cards.map(\.id))
    }

    func receive(_ newCards: [CardSummary]) {
        listCards = newCards
        hasLoadedList = true
        observationError = nil
        guard !isSearching else { return }
        show(newCards)
    }

    private func show(_ newCards: [CardSummary]) {
        cards = newCards
        let ids = Set(newCards.map(\.id))
        selection.formIntersection(ids)
        if let anchorID, !ids.contains(anchorID) {
            self.anchorID = nil
        }
        if let cursorID, !ids.contains(cursorID) {
            self.cursorID = nil
        }
        updateQuickPasteCards()
        if isSearching, selection.isEmpty {
            selectsFirstOnLoad = true
        }
        selectFirstIfPending()
    }

    /// after the first list, only a board that disappears leaves its tab, because a new one can lag a list behind
    func receiveBoards(_ newBoards: [Board]) {
        let previousIDs = hasLoadedBoards ? Set(boards.map(\.id)) : nil
        boards = newBoards
        hasLoadedBoards = true
        boardsDidChange()
        if case let .board(id) = tab, !newBoards.contains(where: { $0.id == id }), previousIDs?.contains(id) ?? true {
            showTab(.history)
        }
    }

    private func updateQuickPasteCards() {
        quickPasteCardIDs = Array(cards.lazy.map(\.id).filter(visibleCardIDs.contains).prefix(9))
    }

    private func selectFirstIfPending() {
        if let id = pendingRevealID, hasLoadedList, !isSearching {
            pendingRevealID = nil
            if index(of: id) != nil {
                selectsFirstOnLoad = false
                select(id)
                revealedID = id
                return
            }
        }
        guard selectsFirstOnLoad, let first = cards.first else { return }
        selectsFirstOnLoad = false
        select(first.id)
    }

    private func clearSelection() {
        selection = []
        anchorID = nil
        cursorID = nil
        revealedID = nil
    }

    private func index(of id: Int64) -> Int? {
        cards.firstIndex { $0.id == id }
    }

    private static func encodeTab(_ list: CardList) -> String {
        switch list {
        case .history: "history"
        case let .board(id): "board:\(id)"
        }
    }

    private static func decodeTab(_ value: String?) -> CardList? {
        guard let value else { return nil }
        if value == "history" {
            return .history
        }
        guard value.hasPrefix("board:"), let id = Int64(value.dropFirst("board:".count)) else { return nil }
        return .board(id: id)
    }
}

extension ShelfModel {
    struct SearchKey: Equatable {
        var text: String
        var filter: CardFilter
    }

    public func observeSearch() async {
        let key = searchKey
        guard isSearching else { return }
        do {
            try await Task.sleep(for: searchDelay)
            for try await results in observeSearchResults(key.text, key.filter) {
                guard key == searchKey else { return }
                receiveResults(results)
            }
        } catch is CancellationError {
            return
        } catch {
            guard key == searchKey else { return }
            Self.logger.error("search failed: \(String(describing: type(of: error)), privacy: .public)")
            observationError = error
        }
    }

    var searchText: String {
        Self.searchText(of: query)
    }

    var searchKey: SearchKey {
        SearchKey(text: searchText, filter: SearchToken.filter(of: tokens))
    }

    var isSearching: Bool {
        !searchText.isEmpty || !tokens.isEmpty
    }

    func searchResult(for id: Int64) -> SearchResult? {
        searchResults[id]
    }

    func board(of card: CardSummary) -> Board? {
        guard isSearching, let boardID = card.boardID else { return nil }
        return boards.first { $0.id == boardID }
    }

    func list(of card: CardSummary) -> CardList {
        guard isSearching, !Self.list(tab, contains: card) else { return tab }
        if card.lastCopiedAt == nil, let boardID = card.boardID {
            return .board(id: boardID)
        }
        return .history
    }

    func idsByList(_ ids: [Int64]) -> [CardList: [Int64]] {
        let selected = Set(ids)
        return Dictionary(grouping: cards.filter { selected.contains($0.id) }, by: list(of:)).mapValues { $0.map(\.id) }
    }

    func removalList(for ids: [Int64]) -> CardList {
        let lists = idsByList(ids).keys
        return lists.count > 1 ? .history : lists.first ?? tab
    }

    func typeToSearch(_ text: String) -> Bool {
        guard !isSearchFieldFocused,
              text.contains(where: { !$0.isWhitespace }),
              text.unicodeScalars.allSatisfy(Self.isTypeable)
        else { return false }
        query += text
        requestedSearchSelection = TextSelection(insertionPoint: query.endIndex)
        isSearchFieldFocused = true
        return true
    }

    func focusSearch() {
        if isSearchFieldFocused, requestedSearchSelection == nil {
            isFilterBrowserPresented = true
        } else {
            requestedSearchSelection = TextSelection(range: query.startIndex ..< query.endIndex)
            isSearchFieldFocused = true
        }
    }

    func searchFieldFocusDidChange(_ isFocused: Bool) {
        isSearchFieldFocused = isFocused
        guard isFocused, let requestedSearchSelection else { return }
        searchSelection = requestedSearchSelection
        self.requestedSearchSelection = nil
    }

    func focusCards() {
        isSearchFieldFocused = false
    }

    func showInList(_ id: Int64) {
        guard isSearching, let card = cards.first(where: { $0.id == id }) else { return }
        let list = list(of: card)
        if list == tab {
            pendingRevealID = id
            resetSearch()
        } else {
            showTab(list)
            pendingRevealID = id
        }
        focusCards()
    }

    func receiveResults(_ results: [SearchResult]) {
        searchResults = Dictionary(results.map { ($0.id, $0) }) { first, _ in first }
        hasLoadedResults = true
        observationError = nil
        show(results.map(\.card))
    }

    private func resetSearch() {
        searchSelection = nil
        requestedSearchSelection = nil
        isFilterBrowserPresented = false
        let wasSearching = isSearching
        isResettingSearch = true
        query = ""
        tokens = []
        isResettingSearch = false
        if wasSearching {
            searchTextDidChange()
        }
    }

    private func searchTextDidChange() {
        selectsFirstOnLoad = true
        guard !isSearching else {
            pendingRevealID = nil
            return
        }
        searchResults = [:]
        hasLoadedResults = false
        show(listCards)
    }

    private static func searchText(of query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func list(_ list: CardList, contains card: CardSummary) -> Bool {
        switch list {
        case .history: card.lastCopiedAt != nil
        case let .board(id): card.boardID == id
        }
    }

    private static func isTypeable(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .format, .privateUse, .surrogate, .unassigned: false
        default: true
        }
    }
}
