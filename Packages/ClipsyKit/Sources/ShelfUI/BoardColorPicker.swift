import DesignSystem
import SwiftUI

/// one tab stop like a text field, so arrows pick a color even with keyboard navigation off
struct BoardColorPicker: View {
    @Binding var selection: BoardColor

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: DesignTokens.spacingMedium) {
            ForEach(BoardColor.allCases, id: \.self) { color in
                Button(color.title) {
                    selection = color
                }
                .buttonStyle(BoardSwatchStyle(
                    color: color,
                    isSelected: color == selection,
                    ringWidth: DesignTokens.selectionRingWidth(for: contrast)
                ))
                .help(color.title)
            }
        }
        .padding(DesignTokens.spacingSmall)
        .focusable(interactions: .edit)
        .onKeyPress(.leftArrow) {
            step(by: -1)
        }
        .onKeyPress(.rightArrow) {
            step(by: 1)
        }
        .accessibilityRepresentation {
            Picker("Color", selection: $selection) {
                ForEach(BoardColor.allCases, id: \.self) { color in
                    Text(color.title).tag(color)
                }
            }
        }
    }

    private func step(by offset: Int) -> KeyPress.Result {
        let palette = BoardColor.allCases
        guard let index = palette.firstIndex(of: selection) else { return .ignored }
        let target = index + offset
        guard palette.indices.contains(target) else { return .handled }
        selection = palette[target]
        return .handled
    }
}

private struct BoardSwatchStyle: ButtonStyle {
    let color: BoardColor
    let isSelected: Bool
    let ringWidth: CGFloat

    func makeBody(configuration _: Configuration) -> some View {
        Circle()
            .fill(color.color)
            .frame(width: DesignTokens.boardSwatchSize, height: DesignTokens.boardSwatchSize)
            .padding(ringWidth + DesignTokens.selectionRingGap)
            .overlay {
                if isSelected {
                    Circle().strokeBorder(.secondary, lineWidth: ringWidth)
                }
            }
            .contentShape(.circle)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
