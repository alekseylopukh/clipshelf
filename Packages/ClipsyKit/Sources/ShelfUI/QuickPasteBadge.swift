import DesignSystem
import SwiftUI

struct QuickPasteBadgeModifier: ViewModifier {
    let number: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    if let number {
                        GlassBadge(count: number)
                            .accessibilityHidden(true)
                            .padding(DesignTokens.badgeInset)
                            .transition(
                                reduceMotion
                                    ? .opacity
                                    : .scale(scale: DesignTokens.badgeEntranceScale).combined(with: .opacity)
                            )
                    }
                }
                .animation(animation, value: number)
            }
            .accessibilityLabel { label in
                label
                if let number {
                    Text(
                        "number \(number)",
                        comment: "Part of a card's VoiceOver label while its Quick Paste badge shows"
                    )
                }
            }
    }

    private var animation: Animation {
        if reduceMotion {
            return DesignTokens.Motion.reduced
        }
        guard let number else { return DesignTokens.Motion.quick }
        return DesignTokens.Motion.pop
            .delay(DesignTokens.badgeAppearDelay + DesignTokens.badgeStagger * Double(number - 1))
    }
}

extension View {
    /// the card strip passes `ShelfModel.quickPasteNumber(for:)`
    func quickPasteBadge(_ number: Int?) -> some View {
        modifier(QuickPasteBadgeModifier(number: number))
    }
}

#Preview {
    HStack(spacing: DesignTokens.cardSpacing) {
        ForEach(1 ... 3, id: \.self) { number in
            RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
                .fill(.background.secondary)
                .frame(width: DesignTokens.cardSide, height: DesignTokens.cardSide)
                .quickPasteBadge(number)
        }
    }
    .padding()
}
