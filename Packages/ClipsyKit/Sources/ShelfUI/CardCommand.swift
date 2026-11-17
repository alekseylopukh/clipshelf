import Store

public enum CardCommand: Hashable, Sendable {
    case paste
    case pasteAsPlainText
    case copy
    case copyAsPlainText
    case open
    case openWith
    case showInFinder
    case quickLook
    case showInList
    case rename
    case edit
    case addToBoard
    case addToSequence
    case removeFromBoard
    case share
    case delete

    static func menu(for cards: [CardSummary], in list: CardList, isSearchResult: Bool) -> [[CardCommand]] {
        let removal: CardCommand = if case .board = list {
            .removeFromBoard
        } else {
            .delete
        }
        let share: [CardCommand] = cards.contains { $0.kind != .unknown } ? [.share] : []
        guard cards.count == 1, let card = cards.first else {
            let sections: [[CardCommand]] = [
                [.paste, .pasteAsPlainText], [.copy], [.addToBoard, .addToSequence], share, [removal]
            ]
            return cards.isEmpty ? [] : sections.filter { !$0.isEmpty }
        }
        let hasPlainText = card.kind != .image && card.kind != .file
        let open: [CardCommand] = switch card.kind {
        case .link: [.open]
        case .file: [.open, .openWith, .showInFinder]
        case .text, .image, .color, .unknown: []
        }
        let sections: [[CardCommand]] = [
            hasPlainText ? [.paste, .pasteAsPlainText] : [.paste],
            hasPlainText ? [.copy, .copyAsPlainText] : [.copy],
            open,
            [.quickLook] + (isSearchResult ? [.showInList] : []) + (card.kind == .text ? [.edit, .rename] : [.rename]),
            [.addToBoard, .addToSequence],
            share,
            [removal]
        ]
        return sections.filter { !$0.isEmpty }
    }
}
