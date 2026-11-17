import AppKit
import Store

extension ShelfController {
    /// a sheet on the panel, because an app-modal alert would take key status and close the shelf
    func confirmDeletion(of count: Int, in list: CardList) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        switch list {
        case .history:
            alert.messageText = String(
                localized: "Delete \(count) cards?",
                comment: "Title of the confirmation shown before deleting several cards from History"
            )
            alert.addButton(withTitle: String(
                localized: "Delete",
                comment: "Context menu item and confirmation button that delete the selected cards"
            ))
        case .board:
            alert.messageText = String(
                localized: "Remove \(count) cards from this board?",
                comment: "Title of the confirmation shown before removing several cards from a board"
            )
            alert.addButton(withTitle: String(
                localized: "Remove",
                comment: "Button that confirms removing cards from a board"
            ))
        }
        alert.informativeText = String(
            localized: "You can undo this until the shelf closes.",
            comment: "Informative text of the confirmation shown before deleting several cards"
        )
        alert.buttons.first?.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Button that dismisses a confirmation"))
        return await alert.beginSheetModal(for: panel) == .alertFirstButtonReturn
    }

    func confirmDeletion(of board: Board) async -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            localized: "Delete the board “\(board.name)”?",
            comment: "Title of the confirmation shown before deleting a board"
        )
        alert.informativeText = String(
            localized: "Its cards stay in History. Cards that are only on this board are deleted. You can’t undo this.",
            comment: "Informative text of the confirmation shown before deleting a board"
        )
        alert.addButton(withTitle: String(
            localized: "Delete",
            comment: "Context menu item and confirmation button that delete the selected cards"
        ))
        alert.buttons.first?.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel", comment: "Button that dismisses a confirmation"))
        return await alert.beginSheetModal(for: panel) == .alertFirstButtonReturn
    }
}
