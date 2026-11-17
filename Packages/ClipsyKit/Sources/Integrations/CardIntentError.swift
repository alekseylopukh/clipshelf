import Foundation

public enum CardIntentError: Error, Equatable, LocalizedError {
    case emptyText
    case duplicateContent
    case noCard(at: Int)
    case noCardOfKind
    case cardNotFound
    case boardNotFound

    public var errorDescription: String? {
        switch self {
        case .emptyText:
            String(localized: "The card has no text.", comment: "Shortcuts error when Create Card gets empty text")
        case .duplicateContent:
            String(
                localized: "A card with the same content already exists.",
                comment: "Shortcuts error when Create Card gets content that is already a card"
            )
        case let .noCard(position):
            String(
                localized: "There is no card at position \(position).",
                comment: "Shortcuts error when Get Card at Index is out of range; the number is the position"
            )
        case .noCardOfKind:
            String(
                localized: "History has no card of this type.",
                comment: "Shortcuts error when Get Latest Card finds no card of the chosen type"
            )
        case .cardNotFound:
            String(
                localized: "The card no longer exists.",
                comment: "Shortcuts error when a card was deleted meanwhile"
            )
        case .boardNotFound:
            String(
                localized: "The board no longer exists.",
                comment: "Shortcuts error when a board was deleted meanwhile"
            )
        }
    }
}
