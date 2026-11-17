import DesignSystem
import Store
import SwiftUI

struct CardHeader: View {
    let card: CardSummary
    let now: Date

    var body: some View {
        HStack(spacing: DesignTokens.spacingMedium) {
            AppIconView(bundleID: card.sourceApp?.bundleID, fallbackSymbol: card.kind.symbolName)
            VStack(alignment: .leading, spacing: 0) {
                if let title = card.title, title.isEmpty == false {
                    Text(title)
                        .font(.headline)
                } else {
                    Text(card.kind.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(now, format: Date.AnchoredRelativeFormatStyle(
                    anchor: card.displayDate,
                    presentation: .named,
                    unitsStyle: .abbreviated
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .lineLimit(1)
        }
    }
}
