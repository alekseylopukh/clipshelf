import Foundation
import Observation
import os
import Store

@MainActor
@Observable
public final class ShelfModel {
    public typealias CardObservation = @Sendable (CardList) -> any AsyncSequence<[CardSummary], any Error> & Sendable

    public enum Direction: Sendable {
        case previous
        case next
    }

    public private(set) var tab: CardList
    public private(set) var cards: [CardSummary] = []
    public private(set) var selection: Set<Int64> = []
    public private(set) var observationError: (any Error)?
    public private(set) var isQuickPasteModifierHeld = false
    private var visibleCardIDs: Set<Int64> = []
    private var quickPasteCardIDs: [Int64] = []

    private var anchorID: Int64?
    private var cursorID: Int64?
    private var selectsFirstOnLoad = true

    @ObservationIgnored private let observe: CardObservation
    @ObservationIgnored private let defaults: UserDefaults

    private static let tabKey = "ShelfTab"
    private static let logger = Logger(subsystem: "app.gonar.clipsy", category: "Shelf")

    public init(defaults: UserDefaults = .standard, observe: @escaping CardObservation) {
        self.defaults = defaults
        self.observe = observe
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

    public func didOpen() {
        clearSelection()
        selectsFirstOnLoad = true
        selectFirstIfPending()
    }

    public func showTab(_ list: CardList) {
        guard list != tab else { return }
        tab = list
        defaults.set(Self.encodeTab(list), forKey: Self.tabKey)
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

    var selectedCards: [CardSummary] {
        cards.filter { selection.contains($0.id) }
    }

    func neighbor(afterRemoving ids: Set<Int64>) -> Int64? {
        guard let last = cards.lastIndex(where: { ids.contains($0.id) }) else { return nil }
        if let next = cards[(last + 1)...].first(where: { !ids.contains($0.id) }) {
            return next.id
        }
        return cards[..<last].last { !ids.contains($0.id) }?.id
    }

    func receive(_ newCards: [CardSummary]) {
        cards = newCards
        observationError = nil
        let ids = Set(newCards.map(\.id))
        selection.formIntersection(ids)
        if let anchorID, !ids.contains(anchorID) {
            self.anchorID = nil
        }
        if let cursorID, !ids.contains(cursorID) {
            self.cursorID = nil
        }
        updateQuickPasteCards()
        selectFirstIfPending()
    }

    private func updateQuickPasteCards() {
        quickPasteCardIDs = Array(cards.lazy.map(\.id).filter(visibleCardIDs.contains).prefix(9))
    }

    private func selectFirstIfPending() {
        guard selectsFirstOnLoad, let first = cards.first else { return }
        selectsFirstOnLoad = false
        select(first.id)
    }

    private func clearSelection() {
        selection = []
        anchorID = nil
        cursorID = nil
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
