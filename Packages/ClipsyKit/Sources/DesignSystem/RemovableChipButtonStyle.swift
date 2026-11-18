import SwiftUI

public struct RemovableChipButtonStyle: PrimitiveButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button(action: configuration.trigger) {
            HStack(spacing: DesignTokens.spacingSmall) {
                configuration.label
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(DesignTokens.searchTokenInsets)
            .background(.fill.secondary, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

public extension PrimitiveButtonStyle where Self == RemovableChipButtonStyle {
    static var removableChip: RemovableChipButtonStyle {
        RemovableChipButtonStyle()
    }
}
