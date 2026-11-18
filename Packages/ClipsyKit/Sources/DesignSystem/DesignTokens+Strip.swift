import SwiftUI

public extension DesignTokens {
    static let shelfOpenSlideDuration: TimeInterval = 0.3
    static let shelfCloseSlideDuration: TimeInterval = 0.22
    static let shelfReducedFadeDuration: TimeInterval = 0.15

    static let cardEntranceDelay: TimeInterval = 0.06
    static let cardEntranceStagger: TimeInterval = 0.025
    static let cardEntranceMaximumIndex = 7
    static let cardEntranceWindow = Duration.milliseconds(350)
    static let cardEntranceOffset: CGFloat = 24

    static let cardVisibilityThreshold: Double = 0.5
    static let stripEdgeOpacity: Double = 0.5
    static let cardTabSlideOffset: CGFloat = 16
    static let cardInsertScale: CGFloat = 0.94
    static let cardInsertDelay: TimeInterval = 0.06
    static let cardRemoveScale: CGFloat = 0.9
    static let emptyStateEntranceScale: CGFloat = 0.96
}
