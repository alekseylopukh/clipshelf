import Store
import SwiftUI

struct CardContextMenu: View {
    let cards: [CardSummary]
    let list: CardList

    @Environment(CardActions.self) private var actions

    var body: some View {
        ForEach(CardCommand.menu(for: cards, in: list), id: \.self) { section in
            Section {
                ForEach(section, id: \.self) { command in
                    CardCommandButton(
                        command: command,
                        targetAppName: actions.targetAppName,
                        plainTextModifiers: actions.plainTextModifier.eventModifiers
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
    let targetAppName: String?
    let plainTextModifiers: EventModifiers
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
            if plainTextModifiers == .command {
                Button("Copy as Plain Text", action: action)
            } else {
                Button("Copy as Plain Text", action: action)
                    .keyboardShortcut("c", modifiers: plainTextModifiers.union(.command))
            }
        case .open:
            Button("Open", action: action)
                .keyboardShortcut("o")
        case .rename:
            Button("Rename…", action: action)
                .keyboardShortcut("r")
        case .removeFromBoard:
            Button("Remove from Board", action: action)
                .keyboardShortcut(.delete, modifiers: [])
        case .delete:
            Button("Delete", systemImage: "trash", role: .destructive, action: action)
                .keyboardShortcut(.delete, modifiers: [])
        }
    }
}
