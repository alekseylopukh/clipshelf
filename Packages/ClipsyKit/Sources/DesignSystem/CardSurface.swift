import SwiftUI

public struct CardSurface: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

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

    public func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(Color(nsColor: DesignTokens.cardFill))
                    .shadow(
                        color: isHovered || isSelected ? DesignTokens.cardLiftShadowColor : .clear,
                        radius: DesignTokens.cardLiftShadowRadius,
                        y: DesignTokens.cardLiftShadowOffset
                    )
            }
            .containerShape(shape)
            .overlay {
                shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: pixelLength)
            }
            .overlay {
                if isSelected {
                    SelectionRing(width: DesignTokens.selectionRingWidth(for: contrast))
                }
            }
            .contentShape(.dragPreview, shape)
            .contentShape(shape)
            .scaleEffect(isSelected ? DesignTokens.cardLiftScale : 1)
            .animation(reduceMotion ? nil : .default, value: isSelected)
            .animation(reduceMotion ? nil : .default, value: isHovered)
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
