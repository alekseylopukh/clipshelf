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

    init(card: CardSummary, now: Date, layout: CardLayout, highlightedTitle: AttributedString?, board: Board?) {
        self.card = card
        self.now = now
        self.layout = layout
        self.highlightedTitle = highlightedTitle
        self.board = board
        _tint = State(initialValue: card.sourceApp.flatMap { AppIconCache.shared.cachedTint(for: $0.bundleID) })
    }

    static func iconPixelSize(layout: CardLayout, displayScale: CGFloat) -> CGFloat {
        iconSize(layout: layout) * displayScale
    }

    private static func visibleIconSize(layout: CardLayout) -> CGFloat {
        layout == .regular ? DesignTokens.cardHeaderIconSize : DesignTokens.cardCompactHeaderIconSize
    }

    private static func iconSize(layout: CardLayout) -> CGFloat {
        visibleIconSize(layout: layout) / DesignTokens.appIconVisibleRatio
    }

    var body: some View {
        let isRegular = layout == .regular
        let contentInset = DesignTokens.cardContentInset
        let visibleIconSize = Self.visibleIconSize(layout: layout)
        let iconInset = isRegular ? DesignTokens.cardHeaderIconInset : DesignTokens.cardCompactHeaderIconInset
        let iconSize = Self.iconSize(layout: layout)
        let band = CardBandColor(tint: tint)
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
                board: board,
                isLightBand: band.isLight(in: environment)
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
                .fill(band.fill(in: environment))
                .animation(DesignTokens.Motion.quick, value: band)
                .padding(.horizontal, -contentInset)
                .padding(.top, -contentInset)
        }
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
}

private struct CardHeaderText: View {
    let card: CardSummary
    let now: Date
    let layout: CardLayout
    let highlightedTitle: AttributedString?
    let board: Board?
    let isLightBand: Bool

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
                    unitsStyle: layout == .regular ? .wide : .narrow
                ))
                .font(DesignTokens.cardHeaderTimeFont)
                .foregroundStyle(DesignTokens.cardHeaderText.opacity(
                    isLightBand || contrast == .increased ? 1 : DesignTokens.cardHeaderSecondaryTextOpacity
                ))
                .monospacedDigit()
                if let board {
                    BoardDot(BoardColor(rawValue: board.color) ?? .gray, isOutlined: true)
                        .help(board.name)
                }
            }
        }
        .lineLimit(1)
        .shadow(
            color: isLightBand ? DesignTokens.cardHeaderTextShadowColor : .clear,
            radius: DesignTokens.cardHeaderTextShadowRadius,
            y: DesignTokens.cardHeaderTextShadowOffset
        )
    }
}
