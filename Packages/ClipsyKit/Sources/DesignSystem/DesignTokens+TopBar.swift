import SwiftUI

public extension DesignTokens {
    static let searchFieldWidth: CGFloat = 220
    static let searchTextMinimumWidth: CGFloat = 80
    static let searchTokenInsets = EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 4)
    static let searchSuggestionInsets = EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
    static let searchSuggestionListCornerRadius: CGFloat = 12
    static let searchSuggestionCornerRadius: CGFloat = searchSuggestionListCornerRadius - spacingSmall
    static let searchSuggestionEntranceScale: CGFloat = 0.96
    static let searchSuggestionEntranceOffset: CGFloat = -8
    static let searchTokenEntranceScale: CGFloat = 0.8

    static let tabTrackPadding: CGFloat = 2
    static let tabSegmentHeight: CGFloat = 24
    static let tabSegmentHorizontalPadding: CGFloat = 10
    static let tabSegmentSpacing: CGFloat = 2
    static let tabSegmentMaximumLabelWidth: CGFloat = 160
    static let tabDropTargetOpacity: Double = 0.25
}
