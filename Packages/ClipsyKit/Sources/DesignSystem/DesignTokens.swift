import SwiftUI

public enum DesignTokens {
    public static let spacingSmall: CGFloat = 4
    public static let spacingMedium: CGFloat = 8
    public static let spacingLarge: CGFloat = 12

    public static let shelfInset: CGFloat = 10
    public static let shelfPadding: CGFloat = 12
    public static let shelfCornerRadius: CGFloat = 26
    public static let cardCornerRadius: CGFloat = shelfCornerRadius - shelfPadding

    public static let cardSide: CGFloat = 220
    public static let compactCardHeightThreshold: CGFloat = 150
    public static let cardSpacing: CGFloat = 12
    public static let cardContentInsets = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    public static let cardHeaderIconSize: CGFloat = 18
    public static let cardLiftScale: CGFloat = 1.02

    public static let selectionRingGap: CGFloat = 2
    public static let boardDotSize: CGFloat = 8
    public static let boardDotOutlineWidth: CGFloat = 1
    public static let badgeSize: CGFloat = 20

    public static func selectionRingWidth(for contrast: ColorSchemeContrast) -> CGFloat {
        contrast == .increased ? 4 : 3
    }
}
