import Store
import SwiftUI

struct CardPopUpAnchor: ViewModifier {
    let card: CardSummary

    @Environment(CardActions.self) private var actions

    func body(content: Content) -> some View {
        content.background {
            if let popUp = actions.popUp, popUp.anchorID == card.id {
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        actions.popUp = nil
                        actions.showPopUp(popUp, proxy.frame(in: .global))
                    }
                }
            }
        }
    }
}

extension View {
    func cardPopUpAnchor(for card: CardSummary) -> some View {
        modifier(CardPopUpAnchor(card: card))
    }
}
