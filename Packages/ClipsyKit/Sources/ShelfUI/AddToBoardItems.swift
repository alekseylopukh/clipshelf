import DesignSystem
import Store
import SwiftUI

struct AddToBoardItems: View {
    let cards: [CardSummary]

    @Environment(BoardEditor.self) private var editor

    var body: some View {
        let ids = cards.map(\.id)
        let boards = editor.boards(forAdding: cards)
        ForEach(boards) { board in
            Button {
                Task {
                    await editor.add(ids, to: board.id)
                }
            } label: {
                Label {
                    Text(board.name)
                } icon: {
                    Image(nsImage: (BoardColor(rawValue: board.color) ?? .gray).menuSwatch)
                }
            }
        }
        if !boards.isEmpty {
            Divider()
        }
        Button("New Board…") {
            editor.beginNew(adding: ids)
        }
    }
}
