import CoreGraphics
import DesignSystem
import Foundation

struct PasteFlightSnapshot {
    let image: CGImage
    let frame: CGRect
    let screenFrame: CGRect
    let scale: CGFloat
    let afterimage: CGImage?
    let afterimageFrame: CGRect
    let cardFrameInAfterimage: CGRect
    let glassFrame: CGRect

    static func contentRect(ofCardFrame cardFrame: CGRect, in bounds: CGRect) -> CGRect {
        // card frames are top-down in the hosting view, which fills the unflipped content view
        CGRect(
            x: cardFrame.minX,
            y: bounds.height - cardFrame.maxY,
            width: cardFrame.width,
            height: cardFrame.height
        ).intersection(bounds)
    }

    static func stripRect(ofCardFrames cardFrames: [CGRect], in bounds: CGRect) -> CGRect {
        guard let first = cardFrames.first else { return .null }
        let union = cardFrames.dropFirst().reduce(first) { $0.union($1) }
        return contentRect(ofCardFrame: union, in: bounds)
    }

    static func cropRect(of cardRect: CGRect, in stripRect: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: (cardRect.minX - stripRect.minX) * scale,
            y: (stripRect.maxY - cardRect.maxY) * scale,
            width: cardRect.width * scale,
            height: cardRect.height * scale
        )
    }

    static func flightDuration(distance: CGFloat) -> TimeInterval {
        min(
            DesignTokens.pasteFlightMaximumDuration,
            max(
                DesignTokens.pasteFlightMinimumDuration,
                DesignTokens.pasteFlightBaseDuration + distance / DesignTokens.pasteFlightPointsPerSecond
            )
        )
    }
}
