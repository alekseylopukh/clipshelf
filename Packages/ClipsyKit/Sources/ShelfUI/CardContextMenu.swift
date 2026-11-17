import KeyboardShortcuts
import Store
import SwiftUI

struct CardContextMenu: View {
    let cards: [CardSummary]
    let list: CardList
    let isSearchResult: Bool
    let openWithApplications: [OpenWithApplication]

    @Environment(CardActions.self) private var actions

    var body: some View {
        ForEach(CardCommand.menu(for: cards, in: list, isSearchResult: isSearchResult), id: \.self) { section in
            Section {
                ForEach(section, id: \.self) { command in
                    CardCommandButton(
                        command: command,
                        cards: cards,
                        targetAppName: actions.targetAppName,
                        plainTextModifiers: actions.plainTextModifier.eventModifiers,
                        isCopyAsPlainTextShortcutTaken: actions.isCopyAsPlainTextShortcutTaken,
                        openWithApplications: openWithApplications
                    ) {
                        actions.perform(command, cards.map(\.id))
                    }
                }
            }
        }
    }
}

struct CardCommandButton: View {
    let command: CardCommand
    let cards: [CardSummary]
    let targetAppName: String?
    let plainTextModifiers: EventModifiers
    let isCopyAsPlainTextShortcutTaken: Bool
    var openWithApplications: [OpenWithApplication] = []
    let action: () -> Void

    var body: some View {
        switch command {
        case .paste:
            if let targetAppName {
                Button("Paste to \(targetAppName)", systemImage: "arrow.down.doc", action: action)
                    .keyboardShortcut(.return, modifiers: [])
            } else {
                Button("Paste", systemImage: "arrow.down.doc", action: action)
                    .keyboardShortcut(.return, modifiers: [])
            }
        case .pasteAsPlainText:
            Button("Paste as Plain Text", systemImage: "textformat", action: action)
                .keyboardShortcut(.return, modifiers: plainTextModifiers)
        case .copy:
            Button("Copy", systemImage: "doc.on.doc", action: action)
                .keyboardShortcut("c")
        case .copyAsPlainText:
            if plainTextModifiers == .command || isCopyAsPlainTextShortcutTaken {
                Button("Copy as Plain Text", action: action)
            } else {
                Button("Copy as Plain Text", action: action)
                    .keyboardShortcut("c", modifiers: plainTextModifiers.union(.command))
            }
        case .open:
            Button("Open", action: action)
                .keyboardShortcut("o")
        case .openWith:
            if let card = cards.first {
                OpenWithMenu(cardID: card.id, applications: openWithApplications)
            }
        case .showInFinder:
            Button("Show in Finder", action: action)
                .keyboardShortcut("r", modifiers: [.shift, .command])
        case .quickLook:
            Button("Quick Look", systemImage: "eye", action: action)
                .keyboardShortcut(.space, modifiers: [])
        case .showInList:
            Button("Show in List", action: action)
                .keyboardShortcut("g")
        case .rename:
            Button("Rename…", action: action)
                .keyboardShortcut("r")
        case .edit:
            Button("Edit…", systemImage: "pencil", action: action)
                .keyboardShortcut("e")
        case .addToBoard:
            AddToBoardMenu(cards: cards)
        case .addToSequence:
            Button("Add to Sequence", systemImage: "list.number", action: action)
                .globalKeyboardShortcut(.startSequence)
        case .removeFromBoard:
            Button("Remove from Board", action: action)
                .keyboardShortcut(.delete, modifiers: [])
        case .share:
            Button("Share…", systemImage: "square.and.arrow.up", action: action)
                .keyboardShortcut("s", modifiers: [.shift, .command])
        case .delete:
            Button("Delete", systemImage: "trash", role: .destructive, action: action)
                .keyboardShortcut(.delete, modifiers: [])
        }
    }
}
