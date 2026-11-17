import SwiftUI

public extension DesignTokens {
    static let shelfOpenAnimation = Animation.spring(duration: 0.3, bounce: 0.04)
    static let shelfCloseAnimation = Animation.spring(duration: 0.2, bounce: 0)
    static let shelfFadeAnimation = Animation.easeInOut(duration: 0.2)

    static let cardEntranceAnimation = Animation.spring(duration: 0.22, bounce: 0)
    static let cardEntranceStagger: TimeInterval = 0.016
    static let cardEntranceMaximumIndex = 8
    static let cardEntranceWindow = Duration.milliseconds(350)
    static let cardEntranceOffset: CGFloat = 6

    static let pasteFlightDuration: TimeInterval = 0.3
    static let pasteFadeDuration: TimeInterval = 0.18
    static let pasteFlightEndScale: CGFloat = 0.15
    static let pasteFlightArcFraction: CGFloat = 0.85
    static let pasteFlightShadowRadius: CGFloat = 12
    static let pasteFlightShadowOpacity: Float = 0.25
}
