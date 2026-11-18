import AppKit
import Carbon.HIToolbox
import Store

extension ShelfModel {
    func handleSelectionKey(keyCode: Int, character: String?, modifiers: NSEvent.ModifierFlags) -> Bool {
        switch (keyCode, modifiers) {
        case (kVK_LeftArrow, []), (kVK_LeftArrow, .shift):
            move(.previous, extending: modifiers == .shift)
        case (kVK_RightArrow, []), (kVK_RightArrow, .shift):
            move(.next, extending: modifiers == .shift)
        case (kVK_UpArrow, .command):
            selectFirst()
        case (kVK_DownArrow, .command):
            selectLast()
        case (_, .command) where character == "a":
            selectAll()
        default:
            return false
        }
        return true
    }

    var selectedCards: [CardSummary] {
        cards.filter { selection.contains($0.id) }
    }

    var selectedCount: Int? {
        selection.count > 1 ? selection.count : nil
    }

    var cursorCard: CardSummary? {
        cards.first { $0.id == cursorID }
    }

    func neighbor(afterRemoving ids: Set<Int64>) -> Int64? {
        guard let last = cards.lastIndex(where: { ids.contains($0.id) }) else { return nil }
        if let next = cards[(last + 1)...].first(where: { !ids.contains($0.id) }) {
            return next.id
        }
        return cards[..<last].last { !ids.contains($0.id) }?.id
    }
}
