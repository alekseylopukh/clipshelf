import CoreGraphics
import DesignSystem

struct PreviewSizeCalculator {
    var defaultSize = CGSize(width: DesignTokens.previewWidth, height: DesignTokens.previewHeight)
    var minimumSide = DesignTokens.previewMinimumSide
    var margin = DesignTokens.previewScreenMargin

    func availableSize(in visibleFrame: CGRect, above shelfGlassFrame: CGRect) -> CGSize {
        CGSize(
            width: visibleFrame.width - 2 * margin,
            height: visibleFrame.maxY - shelfGlassFrame.maxY - margin
        )
    }

    func size(in available: CGSize, imagePixelSize: CGSize? = nil) -> CGSize {
        let scale = min(1, available.width / defaultSize.width, available.height / defaultSize.height)
        let box = CGSize(width: defaultSize.width * scale, height: defaultSize.height * scale)
        guard let imagePixelSize else {
            return CGSize(width: box.width.rounded(.down), height: box.height.rounded(.down))
        }
        let fit = min(box.width / imagePixelSize.width, box.height / imagePixelSize.height)
        let width = min(max(imagePixelSize.width * fit, minimumSide), box.width)
        let height = min(max(imagePixelSize.height * fit, minimumSide), box.height)
        return CGSize(width: width.rounded(.down), height: height.rounded(.down))
    }
}
