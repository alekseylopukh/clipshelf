import SwiftUI

public struct CardSurface: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.pixelLength) private var pixelLength

    public init(isSelected: Bool, isHovered: Bool) {
        self.isSelected = isSelected
        self.isHovered = isHovered
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DesignTokens.cardCornerRadius)
    }

    private var isLifted: Bool {
        isSelected || isHovered
    }

    public func body(content: Content) -> some View {
        content
            .background {
                CardShadowedFill(
                    shape: shape,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    isDark: colorScheme == .dark
                )
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.quick, value: isSelected)
                .animation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.quick, value: isHovered)
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
                            .transition(.asymmetric(insertion: .identity, removal: .opacity))
                    }
                }
                .animation(DesignTokens.Motion.ringFade, value: isSelected)
            }
            .contentShape(.dragPreview, shape)
            .animation(reduceMotion ? nil : DesignTokens.Motion.quick) {
                $0.offset(y: isLifted && !reduceMotion ? -DesignTokens.cardLiftOffset : 0)
            }
            .contentShape(shape)
    }
}

private struct CardShadowedFill: View {
    let shape: RoundedRectangle
    let isSelected: Bool
    let isHovered: Bool
    let isDark: Bool

    private var contactOpacity: Double {
        guard isSelected == false else { return 0 }
        return isDark ? DesignTokens.cardContactShadowOpacityDark : DesignTokens.cardContactShadowOpacity
    }

    private var ambient: AmbientShadow {
        if isSelected {
            AmbientShadow(
                opacity: isDark ? DesignTokens.cardSelectedShadowOpacityDark : DesignTokens.cardSelectedShadowOpacity,
                radius: DesignTokens.cardSelectedShadowRadius,
                y: DesignTokens.cardSelectedShadowOffset
            )
        } else if isHovered {
            AmbientShadow(
                opacity: isDark ? DesignTokens.cardHoverShadowOpacityDark : DesignTokens.cardHoverShadowOpacity,
                radius: DesignTokens.cardHoverShadowRadius,
                y: DesignTokens.cardHoverShadowOffset
            )
        } else {
            AmbientShadow(
                opacity: isDark ? DesignTokens.cardAmbientShadowOpacityDark : DesignTokens.cardAmbientShadowOpacity,
                radius: DesignTokens.cardAmbientShadowRadius,
                y: DesignTokens.cardAmbientShadowOffset
            )
        }
    }

    var body: some View {
        let ambient = ambient
        shape
            .fill(Color(nsColor: DesignTokens.cardFill))
            .shadow(
                color: .black.opacity(contactOpacity),
                radius: DesignTokens.cardContactShadowRadius,
                y: DesignTokens.cardContactShadowOffset
            )
            .shadow(color: .black.opacity(ambient.opacity), radius: ambient.radius, y: ambient.y)
    }
}

private struct AmbientShadow {
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat
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
    func cardSurface(isSelected: Bool, isHovered: Bool) -> some View {
        modifier(CardSurface(isSelected: isSelected, isHovered: isHovered))
    }
}
