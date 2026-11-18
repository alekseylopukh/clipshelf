import AppKit
import DesignSystem
import Store
import SwiftUI

struct BoardContextMenu: View {
    let board: Board

    @Environment(BoardEditor.self) private var editor

    var body: some View {
        Button("Edit Board…", systemImage: "pencil") {
            editor.beginEditing(board)
        }
        .keyboardShortcut("e", modifiers: [.shift, .command])
        Picker("Color", systemImage: "paintpalette", selection: color) {
            ForEach(BoardColor.allCases, id: \.self) { color in
                Label {
                    Text(color.title)
                } icon: {
                    Image(nsImage: color.menuSwatch)
                }
                .tag(color)
            }
        }
        .pickerStyle(.menu)
        Divider()
        Button("Delete Board…", systemImage: "trash", role: .destructive) {
            Task {
                await editor.delete(board)
            }
        }
        .keyboardShortcut(.delete, modifiers: [.shift, .command])
    }

    private var color: Binding<BoardColor> {
        Binding {
            BoardColor(rawValue: board.color) ?? .gray
        } set: { color in
            Task {
                await editor.recolor(board, to: color)
            }
        }
    }
}
