import AppKit
import SwiftUI

public enum DesignTokens {
    public static let spacingSmall: CGFloat = 4
    public static let spacingMedium: CGFloat = 8
    public static let spacingLarge: CGFloat = 12

    public static let shelfInset: CGFloat = 10
    public static let shelfPadding: CGFloat = 12
    public static let shelfCornerRadius: CGFloat = 26
    public static let cardCornerRadius: CGFloat = shelfCornerRadius - shelfPadding
    public static let shelfMinimumHeight: CGFloat = 160
    public static let shelfDefaultHeight: CGFloat = 300
    public static let shelfMaximumHeightFraction: CGFloat = 0.4
    public static let shelfResizeHandleHeight: CGFloat = 6
    public static let shelfOpenOffset: CGFloat = 24
    public static let shelfOpenScale: CGFloat = 0.98

    public static let cardSide: CGFloat = 220
    public static let compactCardHeightThreshold: CGFloat = 150
    public static let cardSpacing: CGFloat = 12
    public static let cardContentInsets = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
    public static let cardHeaderIconSize: CGFloat = 18
    public static let cardLiftScale: CGFloat = 1.02
    public static let cardInnerCornerRadius: CGFloat = cardCornerRadius - cardContentInsets.leading
    public static let cardLiftShadowRadius: CGFloat = 8
    public static let cardLiftShadowOffset: CGFloat = 2
    public static let cardLiftShadowColor = Color.black.opacity(0.18)
    public static let cardFill = NSColor.controlBackgroundColor
    public static let cardFadeHeight: CGFloat = 24
    public static let colorValueInsets = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
    public static let thumbnailMaxPixelSize = 800
    public static let checkerboardSquareSize: CGFloat = 6
    public static let fileIconSize: CGFloat = 96
    public static let fileStackIconSize: CGFloat = 80
    public static let fileStackAngle: Double = 8
    public static let fileStackOffset: CGFloat = 16

    public static let sequencePanelWidth: CGFloat = 280
    public static let sequencePanelScreenInset: CGFloat = 16
    public static let sequencePanelCornerRadius: CGFloat = 18
    public static let sequenceRowHeight: CGFloat = 44
    public static let sequenceRowInsets = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
    public static let sequenceMaximumVisibleRows = 6
    public static let sequenceNextMarkerSize: CGFloat = 6

    public static let settingsListHeight: CGFloat = 120
    public static let settingsListIconSize: CGFloat = 16

    public static let onboardingWidth: CGFloat = 480
    public static let onboardingMinimumHeight: CGFloat = 380
    public static let onboardingIconSize: CGFloat = 64
    public static let onboardingPadding: CGFloat = 20

    public static let selectionRingGap: CGFloat = 2
    public static let boardDotSize: CGFloat = 8
    public static let boardDotOutlineWidth: CGFloat = 1
    public static let badgeSize: CGFloat = 20
    public static let renameFieldWidth: CGFloat = 220

    public static func selectionRingWidth(for contrast: ColorSchemeContrast) -> CGFloat {
        contrast == .increased ? 4 : 3
    }
}
