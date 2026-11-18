import SwiftUI

public struct GlassBadge: View {
    private let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        Text(count, format: .number)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .frame(minWidth: DesignTokens.badgeSize, minHeight: DesignTokens.badgeSize)
            .glassEffect(.regular, in: .capsule)
    }
}
