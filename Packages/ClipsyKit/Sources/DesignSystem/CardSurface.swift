import SwiftUI

public struct CardSurface: ViewModifier {
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.pixelLength) private var pixelLength

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
    }

    public func body(content: Content) -> some View {
        content
            .background {
                CardShadowedFill(shape: shape, isDark: colorScheme == .dark)
            }
            .containerShape(shape)
            .overlay {
                CardEdge(
                    shape: shape,
                    isDark: colorScheme == .dark,
                    isContrastIncreased: contrast == .increased,
                    pixelLength: pixelLength
                )
            }
            .overlay {
                ZStack {
                    if isSelected {
                        SelectionRing(width: DesignTokens.selectionRingWidth(for: contrast))
                    }
                }
                // keeps the ring instant inside the strip's animated card updates
                .animation(nil, value: isSelected)
            }
            .contentShape(.dragPreview, shape)
            .contentShape(shape)
    }
}

private struct CardShadowedFill: View {
    let shape: RoundedRectangle
    let isDark: Bool

    var body: some View {
        shape
            .fill(Color(nsColor: DesignTokens.cardFill))
            .shadow(
                color: .black.opacity(
                    isDark ? DesignTokens.cardContactShadowOpacityDark : DesignTokens.cardContactShadowOpacity
                ),
                radius: DesignTokens.cardContactShadowRadius,
                y: DesignTokens.cardContactShadowOffset
            )
            .shadow(
                color: .black.opacity(
                    isDark ? DesignTokens.cardAmbientShadowOpacityDark : DesignTokens.cardAmbientShadowOpacity
                ),
                radius: DesignTokens.cardAmbientShadowRadius,
                y: DesignTokens.cardAmbientShadowOffset
            )
    }
}

private struct CardEdge: View {
    let shape: RoundedRectangle
    let isDark: Bool
    let isContrastIncreased: Bool
    let pixelLength: CGFloat

    var body: some View {
        if isContrastIncreased {
            shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        } else if isDark {
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(DesignTokens.cardEdgeTopOpacityDark),
                        .white.opacity(DesignTokens.cardEdgeBottomOpacityDark)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: DesignTokens.cardEdgeWidthDark
            )
        } else {
            shape.strokeBorder(.black.opacity(DesignTokens.cardEdgeOpacity), lineWidth: pixelLength)
        }
    }
}

private struct SelectionRing: View {
    let width: CGFloat

    var body: some View {
        let outset = DesignTokens.selectionRingGap + width
        RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius + outset)
            .strokeBorder(Color.accentColor, lineWidth: width)
            .padding(-outset)
            .accessibilityHidden(true)
    }
}

public extension View {
    func cardSurface(isSelected: Bool) -> some View {
        modifier(CardSurface(isSelected: isSelected))
    }
}
