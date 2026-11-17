import Foundation
import Observation

@MainActor
@Observable
public final class PasteSequence {
    public struct Entry: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let cardID: Int64
    }

    private struct Removal {
        var entry: Entry
        var index: Int
    }

    public private(set) var entries: [Entry] = []
    public private(set) var isOpen = false
    public var isReverseOrder = false
    public var isPlainText: Bool {
        didSet { defaults.set(isPlainText, forKey: Self.plainTextKey) }
    }

    private var removals: [Removal] = []

    @ObservationIgnored private let defaults: UserDefaults

    private static let plainTextKey = "SequencePlainText"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isPlainText = defaults.bool(forKey: Self.plainTextKey)
    }

    public var head: Entry? {
        entries.first
    }

    public var canUndo: Bool {
        removals.isEmpty == false
    }

    public func open() {
        isOpen = true
    }

    /// `cardIDs` in the order they should be pasted, for example shelf order or copy order
    public func add(_ cardIDs: [Int64]) {
        let added = cardIDs.map { Entry(id: UUID(), cardID: $0) }
        if isReverseOrder {
            entries.insert(contentsOf: added, at: 0)
        } else {
            entries.append(contentsOf: added)
        }
        isOpen = true
    }

    public func didPaste(_ entryID: Entry.ID) {
        guard take(entryID) else { return }
        if entries.isEmpty {
            close()
        }
    }

    public func remove(_ entryID: Entry.ID) {
        take(entryID)
    }

    public func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.map { entries[$0] }
        let kept = entries.indices.filter { offsets.contains($0) == false }.map { entries[$0] }
        let insertion = destination - offsets.count(in: 0 ..< destination)
        entries = kept
        entries.insert(contentsOf: moving, at: insertion)
    }

    public func undo() {
        guard let removal = removals.popLast() else { return }
        entries.insert(removal.entry, at: min(removal.index, entries.count))
    }

    public func pasteAll() -> [Int64] {
        let cardIDs = entries.map(\.cardID)
        close()
        return cardIDs
    }

    public func clear() {
        entries = []
        removals = []
    }

    public func close() {
        clear()
        isOpen = false
    }

    @discardableResult
    private func take(_ entryID: Entry.ID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return false }
        removals.append(Removal(entry: entries.remove(at: index), index: index))
        return true
    }
}
