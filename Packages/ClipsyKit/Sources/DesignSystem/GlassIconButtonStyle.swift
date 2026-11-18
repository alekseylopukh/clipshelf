import SwiftUI

public struct GlassIconButtonStyle: PrimitiveButtonStyle {
    let isProminent: Bool

    public init(isProminent: Bool = false) {
        self.isProminent = isProminent
    }

    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        if isProminent {
            styled(Button(configuration)).buttonStyle(.glassProminent)
        } else {
            styled(Button(configuration)).buttonStyle(.glass)
        }
    }

    private func styled(_ button: Button<Configuration.Label>) -> some View {
        button
            .labelStyle(.glassIcon)
            .buttonBorderShape(.circle)
            .controlSize(.large)
    }
}

public extension PrimitiveButtonStyle where Self == GlassIconButtonStyle {
    static var glassIcon: GlassIconButtonStyle {
        GlassIconButtonStyle()
    }

    static func glassIcon(isProminent: Bool) -> GlassIconButtonStyle {
        GlassIconButtonStyle(isProminent: isProminent)
    }
}
