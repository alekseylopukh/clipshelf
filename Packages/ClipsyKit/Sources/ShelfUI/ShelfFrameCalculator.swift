import CoreGraphics
import DesignSystem

struct ShelfFrameCalculator {
    var inset = DesignTokens.shelfInset
    var shadowMargin = DesignTokens.shelfShadowMargin
    var minimumHeight = DesignTokens.shelfMinimumHeight
    var maximumHeightFraction = DesignTokens.shelfMaximumHeightFraction

    func clampedHeight(_ height: CGFloat, in visibleFrame: CGRect) -> CGFloat {
        let maximumHeight = max(minimumHeight, visibleFrame.height * maximumHeightFraction)
        return min(max(height, minimumHeight), maximumHeight)
    }

    func glassFrame(height: CGFloat, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.minX + inset,
            y: visibleFrame.minY + inset,
            width: visibleFrame.width - 2 * inset,
            height: clampedHeight(height, in: visibleFrame)
        )
    }

    func windowFrame(height: CGFloat, in visibleFrame: CGRect) -> CGRect {
        glassFrame(height: height, in: visibleFrame).insetBy(dx: -shadowMargin, dy: -shadowMargin)
    }

    func glassHeight(windowHeight: CGFloat) -> CGFloat {
        windowHeight - 2 * shadowMargin
    }
}
