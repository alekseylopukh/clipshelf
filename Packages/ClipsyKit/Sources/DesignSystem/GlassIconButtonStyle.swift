import SwiftUI

public struct GlassIconButtonStyle: PrimitiveButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(configuration)
            .labelStyle(.glassIcon)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
    }
}

public extension PrimitiveButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle {
        GlassIconButtonStyle()
    }
}
