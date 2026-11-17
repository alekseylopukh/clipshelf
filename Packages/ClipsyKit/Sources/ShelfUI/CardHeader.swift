import DesignSystem
import Store
import SwiftUI

struct CardHeader: View {
    let card: CardSummary
    let now: Date
    let layout: CardLayout
    let highlightedTitle: AttributedString?
    let board: Board?

    @State private var tint: AppIconTint?
    @Environment(\.self) private var environment
    @Environment(\.colorSchemeContrast) private var contrast

    init(card: CardSummary, now: Date, layout: CardLayout, highlightedTitle: AttributedString?, board: Board?) {
        self.card = card
        self.now = now
        self.layout = layout
        self.highlightedTitle = highlightedTitle
        self.board = board
        _tint = State(initialValue: card.sourceApp.flatMap { AppIconCache.shared.cachedTint(for: $0.bundleID) })
    }

    var body: some View {
        let isRegular = layout == .regular
        let contentInset = DesignTokens.cardContentInset
        let visibleIconSize = isRegular ? DesignTokens.cardHeaderIconSize : DesignTokens.cardCompactHeaderIconSize
        let iconInset = isRegular ? DesignTokens.cardHeaderIconInset : DesignTokens.cardCompactHeaderIconInset
        let iconSize = visibleIconSize / DesignTokens.appIconVisibleRatio
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: DesignTokens.cardCornerRadius,
            topTrailingRadius: DesignTokens.cardCornerRadius
        )
        HStack(spacing: isRegular ? DesignTokens.spacingMedium : DesignTokens.spacingSmall) {
            CardHeaderText(
                card: card,
                now: now,
                layout: layout,
                highlightedTitle: highlightedTitle,
                board: board
            )
            Spacer(minLength: 0)
            AppIconView(
                bundleID: card.sourceApp?.bundleID,
                fallbackSymbol: card.kind.symbolName,
                size: iconSize,
                fallbackSize: visibleIconSize,
                fallbackColor: DesignTokens.cardHeaderText.opacity(DesignTokens.cardHeaderSecondaryTextOpacity)
            )
        }
        .padding(.trailing, iconInset - contentInset - (iconSize - visibleIconSize) / 2)
        .frame(height: visibleIconSize + 2 * iconInset)
        .padding(.top, -contentInset)
        .background {
            shape
                .fill(bandColor)
                .overlay {
                    shape.fill(LinearGradient(
                        colors: [DesignTokens.cardHeaderSheenColor, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                .padding(.horizontal, -contentInset)
                .padding(.top, -contentInset)
        }
        .padding(.bottom, DesignTokens.spacingSmall)
        .task(id: card.sourceApp?.bundleID) {
            guard let bundleID = card.sourceApp?.bundleID else {
                tint = nil
                return
            }
            tint = AppIconCache.shared.cachedTint(for: bundleID)
            guard tint == nil else { return }
            tint = await AppIconCache.shared.tint(for: bundleID)
        }
    }

    private var bandColor: Color {
        let bandColor = CardBandColor(tint: tint)
        // the text sits mid-band, under half of the sheen
        return bandColor.legibleColor(
            in: environment,
            sheenOpacity: DesignTokens.cardHeaderSheenOpacity / 2,
            minimumContrast: contrast == .increased
                ? DesignTokens.cardHeaderIncreasedTextContrast
                : bandColor.minimumWhiteContrast
        )
    }
}

private struct CardHeaderText: View {
    let card: CardSummary
    let now: Date
    let layout: CardLayout
    let highlightedTitle: AttributedString?
    let board: Board?

    @Environment(CardActions.self) private var actions
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if layout == .regular {
                Button {
                    actions.perform(.rename, [card.id])
                } label: {
                    Group {
                        if let highlightedTitle {
                            Text(highlightedTitle)
                        } else if let title = card.title, title.isEmpty == false {
                            Text(title)
                        } else {
                            Text(card.kind.name)
                        }
                    }
                    .font(DesignTokens.cardHeaderTitleFont)
                    .foregroundStyle(DesignTokens.cardHeaderText)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: DesignTokens.spacingSmall) {
                Text(now, format: Date.AnchoredRelativeFormatStyle(
                    anchor: card.displayDate,
                    presentation: .named,
                    unitsStyle: .abbreviated
                ))
                .font(DesignTokens.cardHeaderTimeFont)
                .foregroundStyle(DesignTokens.cardHeaderText.opacity(
                    contrast == .increased ? 1 : DesignTokens.cardHeaderSecondaryTextOpacity
                ))
                .monospacedDigit()
                if let board {
                    BoardMarker(board: board)
                }
            }
        }
        .lineLimit(1)
        .shadow(
            color: DesignTokens.cardHeaderTextShadowColor,
            radius: DesignTokens.cardHeaderTextShadowRadius,
            y: DesignTokens.cardHeaderTextShadowOffset
        )
    }
}

private struct BoardMarker: View {
    let board: Board

    var body: some View {
        Circle()
            .fill((BoardColor(rawValue: board.color) ?? .gray).color)
            .overlay {
                Circle().strokeBorder(DesignTokens.cardHeaderBoardDotRing, lineWidth: DesignTokens.boardDotOutlineWidth)
            }
            .frame(width: DesignTokens.boardDotSize, height: DesignTokens.boardDotSize)
            .help(board.name)
    }
}
