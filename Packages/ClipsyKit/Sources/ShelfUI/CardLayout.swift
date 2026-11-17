import CoreGraphics
import DesignSystem

enum CardLayout: Equatable {
    case regular
    case compact

    init(stripHeight: CGFloat) {
        let cardHeight = stripHeight - 2 * DesignTokens.shelfPadding
        self = cardHeight < DesignTokens.compactCardHeightThreshold ? .compact : .regular
    }
}
