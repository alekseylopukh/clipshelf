import DesignSystem
import SwiftUI

struct ColorCardPreview: View {
    let swatch: Color?
    let components: ColorComponents?

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(swatch ?? .clear)
                .frame(height: DesignTokens.previewColorSwatchHeight)
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
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
