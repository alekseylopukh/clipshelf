import SwiftUI

public struct GlassTabButtonStyle: PrimitiveButtonStyle {
    let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        Group {
            if isSelected {
                Button(configuration)
                    .buttonStyle(.glassProminent)
                    .accessibilityAddTraits(.isSelected)
            } else {
                Button(configuration)
                    .buttonStyle(.glass)
            }
        }
        .controlSize(.large)
    }
}

public extension PrimitiveButtonStyle where Self == GlassTabButtonStyle {
    static func glassTab(isSelected: Bool) -> GlassTabButtonStyle {
        GlassTabButtonStyle(isSelected: isSelected)
    }
}
