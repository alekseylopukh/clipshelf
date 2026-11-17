import DesignSystem
import SwiftUI

struct QuickPasteBadge: View {
    let number: Int

    var body: some View {
        Text(number, format: .number)
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .frame(minWidth: DesignTokens.badgeSize, minHeight: DesignTokens.badgeSize)
            .glassEffect(.regular, in: .capsule)
            .accessibilityHidden(true)
    }
}

struct QuickPasteBadgeModifier: ViewModifier {
    let number: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                ZStack {
                    if let number {
                        QuickPasteBadge(number: number)
                            .padding(DesignTokens.spacingSmall)
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .default, value: number)
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
