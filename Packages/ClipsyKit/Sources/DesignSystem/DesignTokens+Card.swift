import SwiftUI

public extension DesignTokens {
    /// the icon's visible squircle, without the image's transparent padding
    static let cardHeaderIconSize: CGFloat = 44
    static let cardHeaderIconInset: CGFloat = 10
    static let cardHeaderText = Color.white
    static let cardHeaderSecondaryTextOpacity: Double = 0.85
    static let cardHeaderTitleFont = Font.system(size: 14, weight: .semibold)
    static let cardHeaderTimeFont = Font.subheadline.weight(.medium)
    static let cardHeaderTextShadowColor = Color.black.opacity(0.22)
    static let cardHeaderTextShadowRadius: CGFloat = 1
    static let cardHeaderTextShadowOffset: CGFloat = 0.5
    static let cardHeaderBoardDotRing = Color.white
    static let cardHeaderIncreasedTextContrast: Double = 4.5
    static let appIconTintSampleSide = 32
    static let appIconPrewarmCount = 12

    static let cardLiftOffset: CGFloat = 2
    static let cardContactShadowRadius: CGFloat = 1
    static let cardContactShadowOffset: CGFloat = 1
    static let cardContactShadowOpacity: Double = 0.12
    static let cardContactShadowOpacityDark: Double = 0.40
    static let cardAmbientShadowRadius: CGFloat = 14
    static let cardAmbientShadowOffset: CGFloat = 6
    static let cardAmbientShadowOpacity: Double = 0.14
    static let cardAmbientShadowOpacityDark: Double = 0.36
    static let cardHoverShadowRadius: CGFloat = 20
    static let cardHoverShadowOffset: CGFloat = 10
    static let cardHoverShadowOpacity: Double = 0.20
    static let cardHoverShadowOpacityDark: Double = 0.48
    static let cardSelectedShadowRadius: CGFloat = 18
    static let cardSelectedShadowOffset: CGFloat = 10
    static let cardSelectedShadowOpacity: Double = 0.18
    static let cardSelectedShadowOpacityDark: Double = 0.44
    static let cardEdgeOpacity: Double = 0.06
    static let cardEdgeTopOpacityDark: Double = 0.22
    static let cardEdgeBottomOpacityDark: Double = 0.06
    static let cardEdgeWidthDark: CGFloat = 1

    static let cardBandAmber = Color(.sRGB, red: 0.98, green: 0.718, blue: 0)
    static let cardBandGraphite = Color(.sRGB, red: 0.114, green: 0.114, blue: 0.122)
    static let cardBandGraphiteDark = Color(.sRGB, red: 0.282, green: 0.282, blue: 0.29)
    static let cardBandLightContrast: Double = 3

    static let cardBodyTopInset = spacingLarge
    static let cardCompactBodyTopInset = spacingMedium
    static let cardLinkImageMinimumHeight: CGFloat = 44
    static let cardMediaFillAspectRange: ClosedRange<CGFloat> = 0.5 ... 2
    static let cardCompactTextLineLimit = 2
    static let mediaCaptionInset: CGFloat = 8
    static let mediaCaptionInsets = EdgeInsets(top: 3, leading: 7, bottom: 3, trailing: 7)
    static let swatchValueInset: CGFloat = 12
    static let swatchLabelLuminanceThreshold: Double = 0.179

    static let badgeSize: CGFloat = 22
    static let badgeInset: CGFloat = cardCornerRadius - badgeSize / 2
    static let badgeAppearDelay: TimeInterval = 0.12
    static let badgeStagger: TimeInterval = 0.015
    static let badgeEntranceScale: CGFloat = 0.4
}
