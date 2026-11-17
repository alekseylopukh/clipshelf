import CoreGraphics

struct PasteFlightSnapshot {
    let image: CGImage
    let frame: CGRect
    let screenFrame: CGRect
    let scale: CGFloat

    /// card frames are top-down in the hosting view, which fills the unflipped content view
    static func contentRect(ofCardFrame cardFrame: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(
            x: cardFrame.minX,
            y: bounds.height - cardFrame.maxY,
            width: cardFrame.width,
            height: cardFrame.height
        ).intersection(bounds)
    }
}
