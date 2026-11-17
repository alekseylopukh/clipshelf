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
                    CardCommandButton(command: command, targetAppName: actions.targetAppName) {
                        actions.perform(command, cards.map(\.id))
                    }
                }
            }
        }
    }
}

private struct CardCommandButton: View {
    let command: CardCommand
    let targetAppName: String?
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
                .keyboardShortcut(.return, modifiers: .shift)
        case .copy:
            Button("Copy", systemImage: "doc.on.doc", action: action)
                .keyboardShortcut("c")
        case .copyAsPlainText:
            Button("Copy as Plain Text", action: action)
                .keyboardShortcut("c", modifiers: [.command, .shift])
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
