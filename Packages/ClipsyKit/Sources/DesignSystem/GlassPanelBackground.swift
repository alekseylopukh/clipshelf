import SwiftUI

/// glass as a background layer, so the panel's content keeps label colors instead of vibrant ones
public struct GlassPanelBackground: View {
    let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Color.clear
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}
