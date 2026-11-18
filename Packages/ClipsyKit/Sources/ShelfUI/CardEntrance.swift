import DesignSystem
import SwiftUI

struct CardEntrance: ViewModifier {
    let delay: TimeInterval?

    @State private var hasEntered = false

    static func delay(at index: Int) -> TimeInterval {
        DesignTokens.cardEntranceDelay
            + Double(min(index, DesignTokens.cardEntranceMaximumIndex)) * DesignTokens.cardEntranceStagger
    }

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
