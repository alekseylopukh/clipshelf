import Store
import SwiftUI

struct CardBoardMenuAnchor: ViewModifier {
    let card: CardSummary

    @Environment(CardActions.self) private var actions

    func body(content: Content) -> some View {
        content.background {
            if actions.boardMenuCardID == card.id {
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        actions.boardMenuCardID = nil
                        actions.showBoardMenu(proxy.frame(in: .global))
                    }
                }
            }
        }
    }
}

extension View {
    func cardBoardMenuAnchor(for card: CardSummary) -> some View {
        modifier(CardBoardMenuAnchor(card: card))
    }
}
