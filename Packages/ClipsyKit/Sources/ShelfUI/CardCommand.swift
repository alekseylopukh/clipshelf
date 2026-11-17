import Store

public enum CardCommand: Hashable, Sendable {
    case paste
    case pasteAsPlainText
    case copy
    case copyAsPlainText
    case open
    case rename
    case removeFromBoard
    case delete

    static func menu(for cards: [CardSummary], in list: CardList) -> [[CardCommand]] {
        let removal: CardCommand = if case .board = list {
            .removeFromBoard
        } else {
            .delete
        }
        guard cards.count == 1, let card = cards.first else {
            return cards.isEmpty ? [] : [[.paste, .pasteAsPlainText], [.copy], [removal]]
        }
        let hasPlainText = card.kind != .image && card.kind != .file
        let sections: [[CardCommand]] = [
            hasPlainText ? [.paste, .pasteAsPlainText] : [.paste],
            hasPlainText ? [.copy, .copyAsPlainText] : [.copy],
            card.kind == .link || card.kind == .file ? [.open] : [],
            [.rename],
            [removal]
        ]
        return sections.filter { !$0.isEmpty }
    }
}
