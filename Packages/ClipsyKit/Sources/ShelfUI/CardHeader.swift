import DesignSystem
import Store
import SwiftUI

struct CardHeader: View {
    let card: CardSummary
    let now: Date
    let layout: CardLayout
    let highlightedTitle: AttributedString?
    let board: Board?

    @Environment(CardActions.self) private var actions

    var body: some View {
        HStack(spacing: DesignTokens.spacingMedium) {
            AppIconView(bundleID: card.sourceApp?.bundleID, fallbackSymbol: card.kind.symbolName)
            VStack(alignment: .leading, spacing: 0) {
                if layout == .regular {
                    Button {
                        actions.perform(.rename, [card.id])
                    } label: {
                        if let highlightedTitle {
                            Text(highlightedTitle)
                                .font(.headline)
                        } else if let title = card.title, title.isEmpty == false {
                            Text(title)
                                .font(.headline)
                        } else {
                            Text(card.kind.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: DesignTokens.spacingSmall) {
                    Text(now, format: Date.AnchoredRelativeFormatStyle(
                        anchor: card.displayDate,
                        presentation: .named,
                        unitsStyle: .abbreviated
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    if let board {
                        BoardMarker(board: board)
                    }
                }
            }
            .lineLimit(1)
        }
    }
}

private struct BoardMarker: View {
    let board: Board

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Circle()
            .fill((BoardColor(rawValue: board.color) ?? .gray).color)
            .overlay {
                if contrast == .increased {
                    Circle().strokeBorder(.primary, lineWidth: DesignTokens.boardDotOutlineWidth)
                }
            }
            .frame(width: DesignTokens.boardDotSize, height: DesignTokens.boardDotSize)
            .help(board.name)
    }
}
