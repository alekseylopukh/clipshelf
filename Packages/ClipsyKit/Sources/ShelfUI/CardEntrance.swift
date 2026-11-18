import DesignSystem
import SwiftUI

struct CardEntrance: ViewModifier {
    let delay: TimeInterval?

    @State private var hasEntered = false

    func body(content: Content) -> some View {
        let isWaiting = delay != nil && !hasEntered
        content
            .opacity(isWaiting ? 0 : 1)
            .offset(y: isWaiting ? DesignTokens.cardEntranceOffset : 0)
            .onAppear {
                guard let delay, !hasEntered else { return }
                withAnimation(DesignTokens.Motion.present.delay(delay)) {
                    hasEntered = true
                }
            }
    }
}

extension View {
    func cardEntrance(delay: TimeInterval?) -> some View {
        modifier(CardEntrance(delay: delay))
    }
}
