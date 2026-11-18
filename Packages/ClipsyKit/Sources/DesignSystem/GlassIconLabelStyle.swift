import SwiftUI

/// a fixed glyph box keeps icon-only glass controls as tall as the text capsules
public struct GlassIconLabelStyle: LabelStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Label(configuration)
            .labelStyle(.iconOnly)
            .frame(width: DesignTokens.topBarIconSize, height: DesignTokens.topBarIconSize)
    }
}

public extension LabelStyle where Self == GlassIconLabelStyle {
    static var glassIcon: GlassIconLabelStyle {
        GlassIconLabelStyle()
    }
}
