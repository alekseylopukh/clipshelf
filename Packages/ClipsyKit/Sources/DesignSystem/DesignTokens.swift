import AppKit
import SwiftUI

public enum DesignTokens {
    public static let spacingSmall: CGFloat = 4
    public static let spacingMedium: CGFloat = 8
    public static let spacingLarge: CGFloat = 12

    public static let shelfInset: CGFloat = 8
    public static let shelfShadowMargin: CGFloat = 32
    public static let shelfPadding: CGFloat = 16
    public static let shelfCornerRadius: CGFloat = cardCornerRadius + shelfPadding
    public static let cardCornerRadius: CGFloat = appIconCornerRadiusRatio * cardHeaderIconSize + cardHeaderIconInset
    public static let topBarControlHeight: CGFloat = 28
    public static let topBarIconSize: CGFloat = 16
    public static let shelfMinimumHeight: CGFloat = 160
    public static let shelfDefaultHeight: CGFloat = 324
    public static let shelfMaximumHeightFraction: CGFloat = 0.4
    public static let shelfResizeHandleHeight: CGFloat = 6
    public static let filterBrowserWidth: CGFloat = 260
    public static let filterBrowserHeight: CGFloat = 380

    public static let cardSide: CGFloat = 220
    public static let compactCardHeightThreshold: CGFloat = 150
    public static let compactCardAspectRatio: CGFloat = 4 / 3
    public static let cardSpacing: CGFloat = shelfPadding
    public static let cardContentInset: CGFloat = 12
    public static let cardCompactHeaderIconSize: CGFloat = 24
    public static let cardCompactHeaderIconInset: CGFloat = 4
    public static let appIconSymbolInsetRatio: CGFloat = 0.15
    /// app icon images carry transparent padding: the squircle is 824 of 1024 px
    public static let appIconVisibleRatio: CGFloat = 824.0 / 1024.0
    public static let appIconCornerRadiusRatio: CGFloat = 0.257
    public static let cardInnerCornerRadius: CGFloat = cardCornerRadius - cardContentInset
    public static let cardFill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.165, green: 0.165, blue: 0.173, alpha: 1)
            : .controlBackgroundColor
    }

    public static let cardFadeHeight: CGFloat = 16
    public static let thumbnailMaxPixelSize = 800
    public static let checkerboardSquareSize: CGFloat = 6
    public static let fileIconSize: CGFloat = 96
    public static let fileStackIconSize: CGFloat = 80
    public static let fileStackAngle: Double = 8
    public static let fileStackOffset: CGFloat = 16
    public static let menuIconSize: CGFloat = 16

    public static let sequencePanelWidth: CGFloat = 280
    public static let sequencePanelScreenInset: CGFloat = 16
    public static let sequencePanelCornerRadius: CGFloat = 18
    public static let sequenceListCornerRadius: CGFloat = sequencePanelCornerRadius - spacingMedium
    public static let sequenceRowHeight: CGFloat = 44
    public static let sequenceRowInsets = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
    public static let sequenceMaximumVisibleRows = 6
    public static let sequenceNextMarkerSize: CGFloat = 6

    public static let settingsWidth: CGFloat = 500
    public static let settingsListHeight: CGFloat = 120
    public static let settingsListIconSize: CGFloat = 16
    public static let aboutIconSize: CGFloat = 64
    public static let acknowledgementsWidth: CGFloat = 460
    public static let acknowledgementsHeight: CGFloat = 420

    public static let selectionRingGap: CGFloat = 2
    public static let boardDotSize: CGFloat = 8
    public static let searchHighlightFill = NSColor.findHighlightColor
    public static let searchHighlightText = NSColor.black
    public static let boardDotOutlineWidth: CGFloat = 1
    public static let boardSwatchSize: CGFloat = 20
    public static let boardSheetWidth: CGFloat = 400
    public static let sheetPadding: CGFloat = 20
    public static let renameFieldWidth: CGFloat = 220
    public static let textEditorWidth: CGFloat = 480
    public static let textEditorHeight: CGFloat = 320
    public static let textEditorCornerRadius: CGFloat = 6
    public static let cardFormSheetWidth: CGFloat = 420

    public static func selectionRingWidth(for contrast: ColorSchemeContrast) -> CGFloat {
        contrast == .increased ? 4 : 3
    }
}
