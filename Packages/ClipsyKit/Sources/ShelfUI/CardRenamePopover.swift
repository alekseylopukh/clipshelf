import Store
import SwiftUI

struct CardRenamePopover: ViewModifier {
    let card: CardSummary

    @Environment(CardActions.self) private var actions

    func body(content: Content) -> some View {
        content.popover(isPresented: isPresented, arrowEdge: .top) {
            CardRenameField(title: card.title) { title in
                actions.rename(card.id, title)
                actions.renamingCardID = nil
            }
        }
    }

    private var isPresented: Binding<Bool> {
        Binding {
            actions.renamingCardID == card.id
        } set: { isPresented in
            if !isPresented, actions.renamingCardID == card.id {
                actions.renamingCardID = nil
            }
        }
    }
}

extension View {
    func cardRenamePopover(for card: CardSummary) -> some View {
        modifier(CardRenamePopover(card: card))
    }
}
