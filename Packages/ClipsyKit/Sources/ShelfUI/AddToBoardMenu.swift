import Store
import SwiftUI

struct AddToBoardMenu: View {
    let cards: [CardSummary]

    var body: some View {
        Menu("Add to Board") {
            AddToBoardItems(cards: cards)
        }
    }
}
