import DesignSystem
import SwiftUI

struct ColorCardPreview: View {
    let swatch: Color?
    let components: ColorComponents?

    @Environment(\.pixelLength) private var pixelLength

    var body: some View {
        VStack(spacing: DesignTokens.spacingLarge) {
            RoundedRectangle(cornerRadius: DesignTokens.cardInnerCornerRadius)
                .fill(swatch ?? .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.cardInnerCornerRadius)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: pixelLength)
                }
                .frame(height: DesignTokens.previewSwatchHeight)
                .accessibilityHidden(true)
            if let components {
                Grid(alignment: .leading, horizontalSpacing: DesignTokens.spacingLarge) {
                    ForEach(ColorFormat.allCases) { format in
                        GridRow {
                            Text(format.label)
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                            Text(verbatim: components.formatted(format))
                                .monospaced()
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
