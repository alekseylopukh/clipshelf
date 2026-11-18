import SwiftUI

public struct GlassBadge: View {
    private enum Content {
        case count(Int)
        case value(String)
    }

    private let content: Content

    public init(count: Int) {
        content = .count(count)
    }

    public init(value: String) {
        content = .value(value)
    }

    public var body: some View {
        switch content {
        case let .count(count):
            Text(count, format: .number)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: DesignTokens.badgeSize, minHeight: DesignTokens.badgeSize)
                .glassEffect(.regular, in: .capsule)
        case let .value(value):
            Text(verbatim: value)
                .font(.callout.monospaced())
                .padding(DesignTokens.colorValueInsets)
                .glassEffect(.regular, in: .capsule)
        }
    }
}
