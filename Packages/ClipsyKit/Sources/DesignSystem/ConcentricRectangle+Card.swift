import SwiftUI

public extension Shape where Self == ConcentricRectangle {
    /// concentric with the card's `containerShape`, never tighter than the radius at the card's content inset
    static var cardInner: ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: .fixed(DesignTokens.cardInnerCornerRadius)), isUniform: true)
    }
}
